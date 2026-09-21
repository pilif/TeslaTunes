// Integration test for the actual TeslaTunes conversion path and bundled libraries.
#import <Cocoa/Cocoa.h>
#import <AudioToolbox/AudioToolbox.h>
#include <FLAC++/decoder.h>
#include <flacfile.h>
#include <flacpicture.h>
#include <mp4file.h>
#include <mp4tag.h>
#include <mp4coverart.h>
#include <tpropertymap.h>
#include <vector>
#include <cstdio>
#include <cstdlib>
#include "flac_utils.h"

static void require(bool condition, const char *message) {
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

class SampleVerifier : public FLAC::Decoder::File {
public:
    const std::vector<int32_t> &samples;
    unsigned channels, bits;
    size_t frame = 0;
    bool failed = false;
    SampleVerifier(const std::vector<int32_t> &s, unsigned c, unsigned b)
        : samples(s), channels(c), bits(b) {}
private:
    FLAC__StreamDecoderWriteStatus write_callback(const FLAC__Frame *f,
                                                  const FLAC__int32 *const data[]) override {
        require(f->header.channels == channels, "channel count changed");
        require(f->header.bits_per_sample == bits, "bit depth changed");
        require(f->header.sample_rate == 44100, "sample rate changed");
        for (unsigned i = 0; i < f->header.blocksize; ++i, ++frame) {
            require((frame + 1) * channels <= samples.size(), "extra decoded samples");
            for (unsigned c = 0; c < channels; ++c)
                require(data[c][i] == samples[frame * channels + c], "PCM sample changed");
        }
        return FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE;
    }
    void error_callback(FLAC__StreamDecoderErrorStatus) override { failed = true; }
};

static void roundTrip(NSURL *directory, unsigned bits, unsigned channels) {
    NSString *stem = [NSString stringWithFormat:@"%u-bit-%u-channel", bits, channels];
    NSURL *input = [directory URLByAppendingPathComponent:[stem stringByAppendingString:@".m4a"]];
    NSURL *output = [directory URLByAppendingPathComponent:[stem stringByAppendingString:@".flac"]];
    // More than one second exercises multiple reads and a final partial buffer.
    const UInt32 frames = 44100 + 137;
    std::vector<int32_t> samples(frames * channels);
    const int32_t half = 1 << (bits - 1);
    for (size_t i = 0; i < samples.size(); ++i) {
        samples[i] = static_cast<int32_t>((i * 7919) % (2 * half)) - half;
    }
    samples[0] = 0; samples[1] = -1; samples[2] = half - 1; samples[3] = -half;
    AudioStreamBasicDescription alac = {};
    alac.mSampleRate = 44100;
    alac.mFormatID = kAudioFormatAppleLossless;
    alac.mFormatFlags = bits == 16 ? kAppleLosslessFormatFlag_16BitSourceData : kAppleLosslessFormatFlag_24BitSourceData;
    alac.mChannelsPerFrame = channels;
    alac.mBitsPerChannel = bits;
    UInt32 size = sizeof(alac);
    OSStatus formatStatus = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, nullptr, &size, &alac);
    if (formatStatus != noErr) fprintf(stderr, "ALAC format status: %d (0x%x)\n", formatStatus, formatStatus);
    require(formatStatus == noErr, "ALAC format setup failed");
    ExtAudioFileRef file = nullptr;
    require(ExtAudioFileCreateWithURL((__bridge CFURLRef)input, kAudioFileM4AType, &alac,
                                     nullptr, kAudioFileFlags_EraseFile, &file) == noErr,
            "ALAC creation failed");
    AudioStreamBasicDescription pcm = {};
    pcm.mSampleRate = 44100;
    pcm.mFormatID = kAudioFormatLinearPCM;
    pcm.mFormatFlags = kAudioFormatFlagIsSignedInteger;
    pcm.mBytesPerPacket = pcm.mBytesPerFrame = channels * sizeof(int32_t);
    pcm.mFramesPerPacket = 1;
    pcm.mChannelsPerFrame = channels;
    pcm.mBitsPerChannel = bits;
    require(ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat, sizeof(pcm), &pcm) == noErr,
            "PCM format setup failed");
    AudioBufferList buffer = {};
    buffer.mNumberBuffers = 1;
    buffer.mBuffers[0] = { channels, static_cast<UInt32>(samples.size() * sizeof(int32_t)), samples.data() };
    require(ExtAudioFileWrite(file, frames, &buffer) == noErr, "ALAC encoding failed");
    require(ExtAudioFileDispose(file) == noErr, "ALAC finalization failed");

    NSData *png = [[NSData alloc] initWithBase64EncodedString:
        @"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=" options:0];
    TagLib::ByteVector artwork(static_cast<const char *>(png.bytes), static_cast<unsigned>(png.length));
    {
        TagLib::MP4::File tagged(input.fileSystemRepresentation);
        require(tagged.isValid(), "TagLib could not open ALAC");
        TagLib::PropertyMap props;
        props.insert("TITLE", TagLib::StringList(TagLib::String("TeslaTunes – Zürich", TagLib::String::UTF8)));
        props.insert("ARTIST", TagLib::StringList("Test Artist"));
        props.insert("ALBUM", TagLib::StringList("Test Album"));
        props.insert("TRACKNUMBER", TagLib::StringList("2/10"));
        props.insert("DISCNUMBER", TagLib::StringList("1/2"));
        props.insert("COMMENT", TagLib::StringList("Round-trip fixture"));
        require(tagged.setProperties(props).isEmpty(), "MP4 tags rejected");
        TagLib::MP4::CoverArtList covers;
        covers.append(TagLib::MP4::CoverArt(TagLib::MP4::CoverArt::PNG, artwork));
        tagged.tag()->setItem("covr", TagLib::MP4::Item(covers));
        require(tagged.save(), "MP4 tags not saved");
    }
    require(ConvertM4AToFlac(input, output, nullptr), "TeslaTunes conversion failed");
    SampleVerifier decoder(samples, channels, bits);
    decoder.set_md5_checking(true);
    require(decoder.init(output.fileSystemRepresentation) == FLAC__STREAM_DECODER_INIT_STATUS_OK,
            "FLAC decoder initialization failed");
    require(decoder.process_until_end_of_stream() && !decoder.failed, "FLAC decoding failed");
    require(decoder.frame == frames, "frame count changed");
    require(decoder.finish(), "FLAC MD5 verification failed");
    {
        TagLib::FLAC::File tagged(output.fileSystemRepresentation);
        require(tagged.isValid(), "TagLib could not open FLAC");
        auto props = tagged.properties();
        require(props["TITLE"].toString() == TagLib::String("TeslaTunes – Zürich", TagLib::String::UTF8), "title changed");
        require(props["ARTIST"].toString() == "Test Artist", "artist changed");
        require(props["ALBUM"].toString() == "Test Album", "album changed");
        require(props["TRACKNUMBER"].toString() == "2", "track changed");
        require(props["TRACKTOTAL"].toString() == "10", "track total changed");
        require(props["DISCNUMBER"].toString() == "1", "disc changed");
        require(props["DISCTOTAL"].toString() == "2", "disc total changed");
        require(props["COMMENT"].toString() == "Round-trip fixture", "comment changed");
        auto pictures = tagged.pictureList();
        require(pictures.size() == 1 && pictures.front()->data() == artwork, "cover art changed");
    }
    BOOL cancel = YES;
    NSURL *cancelled = [directory URLByAppendingPathComponent:@"cancelled.flac"];
    require(!ConvertM4AToFlac(input, cancelled, &cancel), "cancelled conversion succeeded");
    require(![[NSFileManager defaultManager] fileExistsAtPath:cancelled.path], "cancelled conversion left output");
    printf("PASS: %u-bit, %u-channel ALAC → FLAC: exact PCM, metadata, cover art, cancellation\n", bits, channels);
}

int main(int argc, const char **argv) {
    @autoreleasepool {
        require(argc == 2, "expected a temporary fixture directory");
        NSURL *directory = [NSURL fileURLWithPath:@(argv[1]) isDirectory:YES];
        for (unsigned bits : {16u, 24u})
            for (unsigned channels : {1u, 2u}) roundTrip(directory, bits, channels);
    }
    return 0;
}
