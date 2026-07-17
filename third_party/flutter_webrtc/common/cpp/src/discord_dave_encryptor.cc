#include "discord_dave_encryptor.h"

#include <stdexcept>
#include <string>

namespace flutter_webrtc_plugin {

namespace {

constexpr int32_t kAudioMediaType = 0;
constexpr int32_t kVideoMediaType = 1;
constexpr int32_t kSuccess = 0;

template <typename Function>
Function RequiredFunction(HMODULE module, const char* name) {
  const auto address = GetProcAddress(module, name);
  if (!address) {
    throw std::runtime_error(std::string("Missing libdave symbol: ") + name);
  }
  return reinterpret_cast<Function>(address);
}

bool IsSilenceFrame(const std::vector<uint8_t>& frame) {
  return frame.size() == 3 && frame[0] == 0xF8 && frame[1] == 0xFF &&
         frame[2] == 0xFE;
}

}  // namespace

DiscordDaveEncryptor::DiscordDaveEncryptor() {
  module_ = GetModuleHandleW(L"libdave.dll");
  if (!module_) {
    module_ = LoadLibraryW(L"libdave.dll");
    owns_module_ = module_ != nullptr;
  }
  if (!module_) {
    throw std::runtime_error("Unable to load libdave.dll");
  }
  get_max_ciphertext_size_ = RequiredFunction<GetMaxCiphertextSize>(
      module_, "daveEncryptorGetMaxCiphertextByteSize");
  encrypt_frame_ =
      RequiredFunction<EncryptFrame>(module_, "daveEncryptorEncrypt");
}

DiscordDaveEncryptor::~DiscordDaveEncryptor() {
  if (owns_module_ && module_) {
    FreeLibrary(module_);
  }
}

std::vector<uint8_t> DiscordDaveEncryptor::EncryptAudio(
    void* encryptor,
    uint32_t ssrc,
    const std::vector<uint8_t>& frame) const {
  if (IsSilenceFrame(frame)) {
    return frame;
  }
  return Encrypt(encryptor, kAudioMediaType, ssrc, frame);
}

std::vector<uint8_t> DiscordDaveEncryptor::EncryptVideo(
    void* encryptor,
    uint32_t ssrc,
    const std::vector<uint8_t>& frame) const {
  return Encrypt(encryptor, kVideoMediaType, ssrc, frame);
}

std::vector<uint8_t> DiscordDaveEncryptor::Encrypt(
    void* encryptor,
    int32_t media_type,
    uint32_t ssrc,
    const std::vector<uint8_t>& frame) const {
  if (!encryptor) {
    throw std::invalid_argument("DAVE encryptor is unavailable");
  }
  if (frame.empty()) {
    throw std::invalid_argument("Media frame is empty");
  }
  const size_t capacity =
      get_max_ciphertext_size_(encryptor, media_type, frame.size());
  if (capacity == 0) {
    throw std::runtime_error("DAVE ciphertext capacity is zero");
  }
  std::vector<uint8_t> output(capacity);
  size_t bytes_written = 0;
  const int32_t result = encrypt_frame_(
      encryptor, media_type, ssrc, frame.data(), frame.size(),
      output.data(), output.size(), &bytes_written);
  if (result != kSuccess || bytes_written > output.size()) {
    throw std::runtime_error("DAVE media encryption failed");
  }
  output.resize(bytes_written);
  return output;
}

}  // namespace flutter_webrtc_plugin
