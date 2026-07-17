#ifndef FLUTTER_WEBRTC_DISCORD_DAVE_ENCRYPTOR_H_
#define FLUTTER_WEBRTC_DISCORD_DAVE_ENCRYPTOR_H_

#include <windows.h>

#include <cstddef>
#include <cstdint>
#include <vector>

namespace flutter_webrtc_plugin {

class DiscordDaveEncryptor {
 public:
  DiscordDaveEncryptor();
  ~DiscordDaveEncryptor();

  DiscordDaveEncryptor(const DiscordDaveEncryptor&) = delete;
  DiscordDaveEncryptor& operator=(const DiscordDaveEncryptor&) = delete;

  std::vector<uint8_t> EncryptAudio(void* encryptor,
                                    uint32_t ssrc,
                                    const std::vector<uint8_t>& frame) const;
  std::vector<uint8_t> EncryptVideo(void* encryptor,
                                    uint32_t ssrc,
                                    const std::vector<uint8_t>& frame) const;

 private:
  std::vector<uint8_t> Encrypt(void* encryptor,
                               int32_t media_type,
                               uint32_t ssrc,
                               const std::vector<uint8_t>& frame) const;
  using GetMaxCiphertextSize = size_t(__cdecl*)(void*, int32_t, size_t);
  using EncryptFrame = int32_t(__cdecl*)(void*,
                                         int32_t,
                                         uint32_t,
                                         const uint8_t*,
                                         size_t,
                                         uint8_t*,
                                         size_t,
                                         size_t*);

  HMODULE module_ = nullptr;
  bool owns_module_ = false;
  GetMaxCiphertextSize get_max_ciphertext_size_ = nullptr;
  EncryptFrame encrypt_frame_ = nullptr;
};

}  // namespace flutter_webrtc_plugin

#endif  // FLUTTER_WEBRTC_DISCORD_DAVE_ENCRYPTOR_H_
