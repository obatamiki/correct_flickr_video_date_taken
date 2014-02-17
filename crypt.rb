#! ruby -EWindows-31J
# -*- mode:ruby; coding:Windows-31J -*-

require 'openssl'

def encrypt_data(data, password, salt)
  cipher = OpenSSL::Cipher::Cipher.new("AES-256-CBC")
  cipher.encrypt
  cipher.pkcs5_keyivgen(password, salt)
  cipher.update(data) + cipher.final
end

def decrypt_data(data, password, salt)
  cipher = OpenSSL::Cipher::Cipher.new("AES-256-CBC")
  cipher.decrypt
  cipher.pkcs5_keyivgen(password, salt)
  cipher.update(data) + cipher.final
end
