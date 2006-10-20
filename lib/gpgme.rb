# Copyright (C) 2003,2006 Daiki Ueno

# This file is a part of Ruby-GPGME.

# This program is free software; you can redistribute it and/or modify 
# it under the terms of the GNU General Public License as published by 
# the Free Software Foundation; either version 2, or (at your option)  
# any later version.                                                   

# This program is distributed in the hope that it will be useful,      
# but WITHOUT ANY WARRANTY; without even the implied warranty of       
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the        
# GNU General Public License for more details.                         

# You should have received a copy of the GNU General Public License    
# along with GNU Emacs; see the file COPYING.  If not, write to the    
# Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301, USA.
 
require 'gpgme_n'
require 'gpgme/constants'

# call-seq:
#   GPGME.decrypt(cipher, plain=nil, options=Hash.new){|signature| ...}
#
# <code>GPGME.decrypt</code> performs decryption.
#
# The arguments should be specified as follows.
# 
# - GPGME.decrypt(<i>cipher</i>, <i>plain</i>, <i>options</i>)
# - GPGME.decrypt(<i>cipher</i>, <i>options</i>) -> <i>plain</i>
#

# All arguments except <i>cipher</i> are optional.  <i>cipher</i> is
# input, and <i>plain</i> is output.  If the last argument is a
# Hash, options will be read from it.
#
# An input argument is specified by an IO like object (which responds
# to <code>read</code>), a string, or a GPGME::Data object.
#
# An output argument is specified by an IO like object (which responds
# to <code>write</code>) or a GPGME::Data object.
#
# <i>options</i> are same as <code>GPGME::Ctx.new()</code>.
#
def GPGME.decrypt(cipher, *args_options, &block)
  raise ArgumentError, 'wrong number of arguments' if args_options.length > 2
  args, options = split_args(args_options)
  plain = args[0]

  ctx = GPGME::Ctx.new(options)
  cipher_data = input_data(cipher)
  plain_data = output_data(plain)
  err = GPGME::gpgme_op_decrypt_verify(ctx, cipher_data, plain_data)
  exc = GPGME::error_to_exception(err)
  raise exc if exc

  verify_result = ctx.verify_result
  if verify_result && block_given?
    verify_result.signatures.each do |signature|
      yield signature
    end
  end

  unless plain
    plain_data.seek(0, IO::SEEK_SET)
    plain_data.read
  end
end

# call-seq:
#   GPGME.verify(sig, signed_text=nil, plain=nil, options=Hash.new){|signature| ...}
#
# <code>GPGME.verify</code> verifies a signature.
#
# The arguments should be specified as follows.
# 
# - GPGME.verify(<i>sig</i>, <i>signed_text</i>, <i>plain</i>, <i>options</i>)
# - GPGME.verify(<i>sig</i>, <i>signed_text</i>, <i>options</i>) -> <i>plain</i>
#
# All arguments except <i>sig</i> are optional.  <i>sig</i> and
# <i>signed_text</i> are input.  <i>plain</i> is output.  If the last
# argument is a Hash, options will be read from it.
#
# An input argument is specified by an IO like object (which responds
# to <code>read</code>), a string, or a GPGME::Data object.
#
# An output argument is specified by an IO like object (which responds
# to <code>write</code>) or a GPGME::Data object.
#
# If <i>sig</i> is a detached signature, then the signed text should
# be provided in <i>signed_text</i> and <i>plain</i> should be
# <tt>nil</tt>.  Otherwise, if <i>sig</i> is a normal (or cleartext)
# signature, <i>signed_text</i> should be <tt>nil</tt>.
#
# <i>options</i> are same as <code>GPGME::Ctx.new()</code>.
#
def GPGME.verify(sig, *args_options, &block) # :yields: signature
  raise ArgumentError, 'wrong number of arguments' if args_options.length > 3
  args, options = split_args(args_options)
  signed_text, plain = args[0]

  ctx = GPGME::Ctx.new(options)
  sig_data = input_data(sig)
  if signed_text
    signed_text_data = input_data(signed_text)
    plain_data = nil
  else
    signed_text_data = nil
    plain_data = output_data(plain)
  end
  err = GPGME::gpgme_op_verify(ctx, sig_data, signed_text_data,
                               plain_data)
  exc = GPGME::error_to_exception(err)
  raise exc if exc

  ctx.verify_result.signatures.each do |signature|
    yield signature
  end
  unless plain
    plain_data.seek(0, IO::SEEK_SET)
    plain_data.read
  end
end

# call-seq:
#   GPGME.sign(plain, sig=nil, options=Hash.new)
#
# <code>GPGME.sign</code> creates a signature of the plaintext.
#
# The arguments should be specified as follows.
# 
# - GPGME.sign(<i>plain</i>, <i>sig</i>, <i>options</i>)
# - GPGME.sign(<i>plain</i>, <i>options</i>) -> <i>sig</i>
#
# All arguments except <i>plain</i> are optional.  <i>plain</i> is
# input and <i>sig</i> is output.  If the last argument is a Hash,
# options will be read from it.
#
# An input argument is specified by an IO like object (which responds
# to <code>read</code>), a string, or a GPGME::Data object.
#
# An output argument is specified by an IO like object (which responds
# to <code>write</code>) or a GPGME::Data object.
#
# <i>options</i> are same as <code>GPGME::Ctx.new()</code> except for
#
# - <tt>:signers</tt> Signing keys.  If specified, it is an array
#   whose elements are a GPGME::Key object or a string.
# - <tt>:mode</tt> Desired type of a signature.  Either
#   <tt>GPGME::SIG_MODE_NORMAL</tt> for a normal signature,
#   <tt>GPGME::SIG_MODE_DETACH</tt> for a detached signature, or
#   <tt>GPGME::SIG_MODE_CLEAR</tt> for a cleartext signature.
#
def GPGME.sign(plain, *args_options)
  raise ArgumentError, 'wrong number of arguments' if args_options.length > 2
  args, options = split_args(args_options)
  sig = args[0]

  ctx = GPGME::Ctx.new(options)
  ctx.add_signer(find_keys(options[:signers]), true) if options[:signers]
  mode = options[:mode] || GPGME::SIG_MODE_NORMAL
  plain_data = input_data(plain)
  sig_data = output_data(sig)
  err = GPGME::gpgme_op_sign(ctx, plain_data, sig_data, mode)
  exc = GPGME::error_to_exception(err)
  raise exc if exc

  unless sig
    sig_data.seek(0, IO::SEEK_SET)
    sig_data.read
  end
end

# call-seq:
#   GPGME.encrypt(recipients, plain, cipher=nil, options=Hash.new)
#
# <code>GPGME.encrypt</code> performs encryption.
#
# The arguments should be specified as follows.
# 
# - GPGME.encrypt(<i>recipients</i>, <i>plain</i>, <i>cipher</i>, <i>options</i>)
# - GPGME.encrypt(<i>recipients</i>, <i>plain</i>, <i>options</i>) -> <i>cipher</i>
#
# All arguments except <i>recipients</i> and <i>plain</i> are
# optional.  <i>plain</i> is input and <i>cipher</i> is output.  If
# the last argument is a Hash, options will be read from it.
#
# The recipients are specified by an array whose elements are a string
# or a GPGME::Key object.  If <i>recipients</i> is <tt>nil</tt>, it
# performs symmetric encryption.
#
# <i>options</i> are same as <code>GPGME::Ctx.new()</code> except for
#
# - <tt>:sign</tt> If <tt>true</tt>, it performs a combined sign and
# encrypt operation.
#
def GPGME.encrypt(recipients, plain, *args_options)
  raise ArgumentError, 'wrong number of arguments' if args_options.length > 3
  args, options = split_args(args_options)
  cipher = args[0]
  recipient_keys = recipients ? find_keys(recipients, false) : nil

  ctx = GPGME::Ctx.new(options)
  plain_data = input_data(plain)
  cipher_data = output_data(cipher)
  err = GPGME::gpgme_op_encrypt(ctx, recipient_keys, 0, plain_data,
                                cipher_data)
  exc = GPGME::error_to_exception(err)
  raise exc if exc

  unless cipher
    cipher_data.seek(0, IO::SEEK_SET)
    cipher_data.read
  end
end

# call-seq:
#   GPGME.each_key(pattern=nil, secret_only=false, options=Hash.new)
#
# <code>GPGME.each_key</code> iterates over the keyring.
#
# The arguments should be specified as follows.
# 
# - GPGME.each_key(<i>pattern</i>, <i>secret_only</i>, <i>options</i>)
#
# All arguments are optional.  If the last argument is a Hash, options
# will be read from it.
#
# <i>pattern</i> is a string or <tt>nil</tt>.  If <i>pattern</i> is
# <tt>nil</tt>, all available keys are returned.  If
# <i>secret_only</i> is <tt>true</tt>, the only secret keys are
# returned.
#
def GPGME.each_key(*args_options) # :yields: key
  raise ArgumentError, 'wrong number of arguments' if args_options.length > 3
  args, options = split_args(args_options)
  pattern, secret_only = args[0]
  ctx = GPGME::Ctx.new
  ctx.each_key(pattern, secret_only || false) do |key|
    yield key
  end
end

module GPGME
  # :stopdoc:
  private

  def split_args(args_options)
    if args_options.length > 0 and args_options[-1].respond_to? :to_hash
      args = args_options[0 ... -1]
      options = args_options[-1]
    else
      args = args_options
      options = Hash.new
    end
    [args, options]
  end
  module_function :split_args

  def find_keys(keys_or_names, secret_only)
    ctx = GPGME::Ctx.new
    keys = Array.new
    keys_or_names.each do |key_or_name|
      if key_or_name.kind_of? Key
        keys << key_or_name
      elsif key_or_name.kind_of? String
        keys += ctx.keys(key_or_name)
      end
    end
    keys
  end
  module_function :find_keys

  def input_data(input)
    if input.kind_of? GPGME::Data
      input
    elsif input.respond_to? :to_str
      GPGME::Data.new_from_mem(input.to_str)
    elsif input.respond_to? :read
      GPGME::Data.new_from_callbacks(IOCallbacks.new(input))
    else
      raise ArgumentError, input.inspect
    end
  end
  module_function :input_data

  def output_data(output)
    if output.kind_of? GPGME::Data
      output
    elsif output.respond_to? :write
      GPGME::Data.new_from_callbacks(IOCallbacks.new(output))
    elsif !output
      GPGME::Data.new
    else
      raise ArgumentError, output.inspect
    end
  end
  module_function :output_data

  class IOCallbacks
    def initialize(io)
      @io = io
    end

    def read(hook, length)
      @io.read(length)
    end

    def write(hook, buffer, length)
      @io.write(buffer[0 .. length])
    end

    def seek(hook, offset, whence)
      return @io.pos if offset == 0 && whence == IO::SEEK_CUR
      @io.seek(offset, whence)
      @io.pos
    end
  end
  # :startdoc:
end

module GPGME
  PROTOCOL_NAMES = {
    PROTOCOL_OpenPGP => :OpenPGP,
    PROTOCOL_CMS => :CMS
  }

  KEYLIST_MODE_NAMES = {
    KEYLIST_MODE_LOCAL => :local,
    KEYLIST_MODE_EXTERN => :extern,
    KEYLIST_MODE_SIGS => :sigs,
    KEYLIST_MODE_VALIDATE => :validate
  }

  VALIDITY_NAMES = {
    VALIDITY_UNKNOWN => :unknown,
    VALIDITY_UNDEFINED => :undefined,
    VALIDITY_NEVER => :never,
    VALIDITY_MARGINAL => :marginal,
    VALIDITY_FULL => :full,
    VALIDITY_ULTIMATE => :ultimate
  }

  class Error < StandardError
    def initialize(error)
      @error = error
    end
    attr_reader :error

    # The error code indicates the type of an error, or the reason why
    # an operation failed.
    def code
      GPGME::gpgme_err_code(@error)
    end

    def source
      GPGME::gpgme_err_source(@error)
    end

    def message
      GPGME::gpgme_strerror(@error)
    end

    class General < self; end
    class InvalidValue < self; end
    class UnusablePublicKey < self; end
    class UnusableSecretKey < self; end
    class NoData < self; end
    class Conflict < self; end
    class NotImplemented < self; end
    class DecryptFailed < self; end
    class BadPassphrase < self; end
    class Canceled < self; end
    class InvalidEngine < self; end
    class AmbiguousName < self; end
    class WrongKeyUsage < self; end
    class CertificateRevoked < self; end
    class CertificateExpired < self; end
    class NoCRLKnown < self; end
    class NoPolicyMatch < self; end
    class NoSecretKey < self; end
    class MissingCertificate < self; end
    class BadCertificateChain < self; end
    class UnsupportedAlgorithm < self; end
    class BadSignature < self; end
    class NoPublicKey < self; end
  end

  def error_to_exception(err)   # :nodoc:
    case GPGME::gpgme_err_code(err)
    when GPG_ERR_EOF
      EOFError.new
    when GPG_ERR_NO_ERROR
      nil
    when GPG_ERR_GENERAL
      Error::General.new(err)
    when GPG_ERR_ENOMEM
      Errno::ENOMEM.new
    when GPG_ERR_INV_VALUE
      Error::InvalidValue.new(err)
    when GPG_ERR_UNUSABLE_PUBKEY
      Error::UnusablePublicKey.new(err)
    when GPG_ERR_UNUSABLE_SECKEY
      Error::UnusableSecretKey.new(err)
    when GPG_ERR_NO_DATA
      Error::NoData.new(err)
    when GPG_ERR_CONFLICT
      Error::Conflict.new(err)
    when GPG_ERR_NOT_IMPLEMENTED
      Error::NotImplemented.new(err)
    when GPG_ERR_DECRYPT_FAILED
      Error::DecryptFailed.new(err)
    when GPG_ERR_BAD_PASSPHRASE
      Error::BadPassphrase.new(err)
    when GPG_ERR_CANCELED
      Error::Canceled.new(err)
    when GPG_ERR_INV_ENGINE
      Error::InvalidEngine.new(err)
    when GPG_ERR_AMBIGUOUS_NAME
      Error::AmbiguousName.new(err)
    when GPG_ERR_WRONG_KEY_USAGE
      Error::WrongKeyUsage.new(err)
    when GPG_ERR_CERT_REVOKED
      Error::CertificateRevoked.new(err)
    when GPG_ERR_CERT_EXPIRED
      Error::CertificateExpired.new(err)
    when GPG_ERR_NO_CRL_KNOWN
      Error::NoCRLKnown.new(err)
    when GPG_ERR_NO_POLICY_MATCH
      Error::NoPolicyMatch.new(err)
    when GPG_ERR_NO_SECKEY
      Error::NoSecretKey.new(err)
    when GPG_ERR_MISSING_CERT
      Error::MissingCertificate.new(err)
    when GPG_ERR_BAD_CERT_CHAIN
      Error::BadCertificateChain.new(err)
    when GPG_ERR_UNSUPPORTED_ALGORITHM
      Error::UnsupportedAlgorithm.new(err)
    when GPG_ERR_BAD_SIGNATURE
      Error::BadSignature.new(err)
    when GPG_ERR_NO_PUBKEY
      Error::NoPublicKey.new(err)
    else
      Error.new(err)
    end
  end
  module_function :error_to_exception
  private :error_to_exception

  def engine_info
    rinfo = Array.new
    GPGME::gpgme_get_engine_info(rinfo)
    rinfo
  end
  module_function :engine_info

  # A class for managing data buffers.
  class Data
    BLOCK_SIZE = 4096

    # Create a new instance.
    def self.new
      rdh = Array.new
      err = GPGME::gpgme_data_new(rdh)
      exc = GPGME::error_to_exception(err)
      raise exc if exc
      rdh[0]
    end

    # Create a new instance with internal buffer.
    def self.new_from_mem(buf, copy = false)
      rdh = Array.new
      err = GPGME::gpgme_data_new_from_mem(rdh, buf, buf.length, copy ? 1 : 0)
      exc = GPGME::error_to_exception(err)
      raise exc if exc
      rdh[0]
    end

    # Create a new instance from the specified file.
    def self.new_from_file(filename, copy = false)
      rdh = Array.new
      err = GPGME::gpgme_data_new_from_file(rdh, filename, copy ? 1 : 0)
      exc = GPGME::error_to_exception(err)
      raise exc if exc
      rdh[0]
    end

    # Create a new instance from the specified file descriptor.
    def self.new_from_fd(fd)
      rdh = Array.new
      err = GPGME::gpgme_data_new_from_fd(rdh, fd)
      exc = GPGME::error_to_exception(err)
      raise exc if exc
      rdh[0]
    end

    # Create a new instance from the specified callbacks.
    def self.new_from_callbacks(callbacks, hook_value = nil)
      rdh = Array.new
      err = GPGME::gpgme_data_new_from_cbs(rdh, callbacks, hook_value)
      exc = GPGME::error_to_exception(err)
      raise exc if exc
      rdh[0]
    end

    # Read at most <i>length</i> bytes from the data object, or to the end
    # of file if <i>length</i> is omitted or is <tt>nil</tt>.
    def read(length = nil)
      if length
	GPGME::gpgme_data_read(self, length)
      else
	buf = String.new
        loop do
          s = GPGME::gpgme_data_read(self, BLOCK_SIZE)
          break unless s
          buf << s
        end
        buf
      end
    end

    # Seek to a given <i>offset</i> in the data object according to the
    # value of <i>whence</i>.
    def seek(offset, whence = IO::SEEK_SET)
      GPGME::gpgme_data_seek(self, offset, IO::SEEK_SET)
    end

    # Write _length_ bytes from _buffer_ into the data object.
    def write(buffer, length = buffer.length)
      GPGME::gpgme_data_write(self, buffer, length)
    end

    # Return the encoding of the underlying data.
    def encoding
      GPGME::gpgme_data_get_encoding(self)
    end

    # Set the encoding to a given _encoding_ of the underlying data object.
    def encoding=(encoding)
      err = GPGME::gpgme_data_set_encoding(self, encoding)
      exc = GPGME::error_to_exception(err)
      raise exc if exc
      encoding
    end
  end

  class EngineInfo
    private_class_method :new
    
    attr_reader :protocol, :file_name, :version, :req_version
    alias required_version req_version
  end

  # A context within which all cryptographic operations are performed.
  class Ctx
    # Create a new instance from the given <i>options</i>.
    # <i>options</i> is a Hash whose keys are
    #
    # * <tt>:protocol</tt>  Either <tt>PROTOCOL_OpenPGP</tt> or
    #   <tt>PROTOCOL_CMS</tt>.
    #
    # * <tt>:armor</tt>  If <tt>true</tt>, the output should be ASCII armored.
    #
    # * <tt>:textmode</tt>  If <tt>true</tt>, inform the recipient that the
    #   input is text.
    #
    # * <tt>:keylist_mode</tt>  Either
    #   <tt>KEYLIST_MODE_LOCAL</tt>,
    #   <tt>KEYLIST_MODE_EXTERN</tt>,
    #   <tt>KEYLIST_MODE_SIGS</tt>, or
    #   <tt>KEYLIST_MODE_VALIDATE</tt>.
    # * <tt>:passphrase_callback</tt>  A callback function.
    # * <tt>:passphrase_callback_value</tt> An object passed to
    #   passphrase_callback.
    # * <tt>:progress_callback</tt>  A callback function.
    # * <tt>:progress_callback_value</tt> An object passed to
    #   progress_callback.
    #
    def self.new(options = Hash.new)
      rctx = Array.new
      err = GPGME::gpgme_new(rctx)
      exc = GPGME::error_to_exception(err)
      raise exc if exc
      ctx = rctx[0]
      options.each_pair do |key, value|
        case key
        when :protocol
          ctx.protocol = value
        when :armor
          ctx.armor = value
        when :textmode
          ctx.textmode = value
        when :keylist_mode
          ctx.keylist_mode = value
        when :passphrase_callback
          ctx.set_passphrase_callback(value,
                                      options[:passphrase_callback_value])
        when :progress_callback
          ctx.set_progress_callback(value,
                                      options[:progress_callback_value])
        end
      end
      ctx
    end

    # Set the <i>protocol</i> used within this context.
    def protocol=(proto)
      err = GPGME::gpgme_set_protocol(self, proto)
      exc = GPGME::error_to_exception(err)
      raise exc if exc
      proto
    end

    # Return the protocol used within this context.
    def protocol
      GPGME::gpgme_get_protocol(self)
    end

    # Tell whether the output should be ASCII armored.
    def armor=(yes)
      GPGME::gpgme_set_armor(self, yes ? 1 : 0)
      yes
    end

    # Return true if the output is ASCII armored.
    def armor
      GPGME::gpgme_get_armor(self) == 1 ? true : false
    end

    # Tell whether canonical text mode should be used.
    def textmode=(yes)
      GPGME::gpgme_set_textmode(self, yes ? 1 : 0)
      yes
    end

    # Return true if canonical text mode is enabled.
    def textmode
      GPGME::gpgme_get_textmode(self) == 1 ? true : false
    end

    # Change the default behaviour of the key listing functions.
    def keylist_mode=(mode)
      GPGME::gpgme_set_keylist_mode(self, mode)
      mode
    end

    # Return the current key listing mode.
    def keylist_mode
      GPGME::gpgme_get_keylist_mode(self)
    end

    def inspect
      "#<#{self.class} protocol=#{PROTOCOL_NAMES[protocol] || protocol}, \
armor=#{armor}, textmode=#{textmode}, \
keylist_mode=#{KEYLIST_MODE_NAMES[keylist_mode]}>"
    end

    # Set the passphrase callback with given hook value.
    # <i>passfunc</i> should respond to <code>call</code> with 5 arguments.
    #
    #  def passfunc(hook, uid_hint, passphrase_info, prev_was_bad, fd)
    #    $stderr.write("Passphrase for #{uid_hint}: ")
    #    $stderr.flush
    #    begin
    #      system('stty -echo')
    #      io = IO.for_fd(fd, 'w')
    #      io.puts(gets)
    #      io.flush
    #    ensure
    #      (0 ... $_.length).each do |i| $_[i] = ?0 end if $_
    #      system('stty echo')
    #    end
    #    puts
    #  end
    #
    #  ctx.set_passphrase_callback(method(:passfunc))
    #
    def set_passphrase_callback(passfunc, hook_value = nil)
      GPGME::gpgme_set_passphrase_cb(self, passfunc, hook_value)
    end
    alias set_passphrase_cb set_passphrase_callback

    # Set the progress callback with given hook value.
    # <i>progfunc</i> should respond to <code>call</code> with 5 arguments.
    #
    #  def progfunc(hook, what, type, current, total)
    #    $stderr.write("#{what}: #{current}/#{total}\r")
    #    $stderr.flush
    #  end
    #
    #  ctx.set_progress_callback(method(:progfunc))
    #
    def set_progress_callback(progfunc, hook_value = nil)
      GPGME::gpgme_set_progress_cb(self, progfunc, hook_value)
    end
    alias set_progress_cb set_progress_callback

    # Initiate a key listing operation for given pattern.
    # If <i>pattern</i> is <tt>nil</tt>, all available keys are
    # returned.  If <i>secret_only</i> is <tt>true</tt>, the only
    # secret keys are returned.
    def keylist_start(pattern = nil, secret_only = false)
      err = GPGME::gpgme_op_keylist_start(self, pattern, secret_only ? 1 : 0)
      exc = GPGME::error_to_exception(err)
      raise exc if exc
    end

    # Advance to the next key in the key listing operation.
    def keylist_next
      rkey = Array.new
      err = GPGME::gpgme_op_keylist_next(self, rkey)
      exc = GPGME::error_to_exception(err)
      raise exc if exc
      rkey[0]
    end

    # End a pending key list operation.
    def keylist_end
      err = GPGME::gpgme_op_keylist_end(self)
      exc = GPGME::error_to_exception(err)
      raise exc if exc
    end

    # Convenient method to iterate over keys.
    # If <i>pattern</i> is <tt>nil</tt>, all available keys are
    # returned.  If <i>secret_only</i> is <tt>true</tt>, the only
    # secret keys are returned.
    def each_key(pattern = nil, secret_only = false, &block) # :yields: key
      keylist_start(pattern, secret_only)
      begin
	loop do
	  yield keylist_next
	end
      rescue EOFError
	# The last key in the list has already been returned.
      ensure
	keylist_end
      end
    end
    alias each_keys each_key

    def keys(pattern = nil, secret_only = nil)
      keys = Array.new
      each_key(pattern, secret_only) do |key|
        keys << key
      end
      keys
    end

    # Get the key with the <i>fingerprint</i>.
    # If <i>secret</i> is <tt>true</tt>, secret key is returned.
    def get_key(fingerprint, secret = false)
      rkey = Array.new
      err = GPGME::gpgme_get_key(self, fingerprint, rkey, secret ? 1 : 0)
      exc = GPGME::error_to_exception(err)
      raise exc if exc
      rkey[0]
    end

    # Generate a new key pair.
    # <i>parms</i> is a string which looks like
    #
    #  <GnupgKeyParms format="internal">
    #  Key-Type: DSA
    #  Key-Length: 1024
    #  Subkey-Type: ELG-E
    #  Subkey-Length: 1024
    #  Name-Real: Joe Tester
    #  Name-Comment: with stupid passphrase
    #  Name-Email: joe@foo.bar
    #  Expire-Date: 0
    #  Passphrase: abc
    #  </GnupgKeyParms>
    #
    # If <i>pubkey</i> and <i>seckey</i> are both set to <tt>nil</tt>,
    # it stores the generated key pair into your key ring.
    def generate_key(parms, pubkey = Data.new, seckey = Data.new)
      err = GPGME::gpgme_op_genkey(self, parms, pubkey, seckey)
      exc = GPGME::error_to_exception(err)
      raise exc if exc
    end
    alias genkey generate_key

    def generate_key_start(parms, pubkey, seckey)
      err = GPGME::gpgme_op_genkey_start(self, parms, pubkey, seckey)
      exc = GPGME::error_to_exception(err)
      raise exc if exc
    end
    alias genkey_start generate_key_start

    # Extract the public keys of the recipients.
    def export_keys(recipients)
      keydata = Data.new
      err = GPGME::gpgme_op_export(self, recipients, keydata)
      exc = GPGME::error_to_exception(err)
      raise exc if exc
      keydata
    end
    alias export export_keys

    # Add the keys in the data buffer to the key ring.
    def import_keys(keydata)
      err = GPGME::gpgme_op_import(self, keydata)
      exc = GPGME::error_to_exception(err)
      raise exc if exc
    end
    alias import import_keys

    # Delete the key from the key ring.
    # If allow_secret is false, only public keys are deleted,
    # otherwise secret keys are deleted as well.
    def delete_key(key, allow_secret = false)
      err = GPGME::gpgme_op_delete(self, key, allow_secret ? 1 : 0)
      exc = GPGME::error_to_exception(err)
      raise exc if exc
    end
    alias delete delete_key

    # Decrypt the ciphertext and return the plaintext.
    def decrypt(cipher, plain = Data.new)
      err = GPGME::gpgme_op_decrypt(self, cipher, plain)
      exc = GPGME::error_to_exception(err)
      raise exc if exc
      plain
    end

    def decrypt_result
      GPGME::gpgme_op_decrypt_result(self)
    end

    # Verify that the signature in the data object is a valid signature.
    def verify(sig, signed_text = nil, plain = Data.new)
      err = GPGME::gpgme_op_verify(self, sig, signed_text, plain)
      exc = GPGME::error_to_exception(err)
      raise exc if exc
      plain
    end

    def verify_result
      GPGME::gpgme_op_verify_result(self)
    end

    # Decrypt the ciphertext and return the plaintext.
    def decrypt_verify(cipher, plain = Data.new)
      err = GPGME::gpgme_op_decrypt_verify(self, cipher, plain)
      exc = GPGME::error_to_exception(err)
      raise exc if exc
      plain
    end

    # Remove the list of signers from this object.
    def clear_signers
      GPGME::gpgme_signers_clear(self)
    end

    # Add _keys_ to the list of signers.
    def add_signer(*keys)
      keys.each do |key|
        err = GPGME::gpgme_signers_add(self, key)
        exc = GPGME::error_to_exception(err)
        raise exc if exc
      end
    end

    # Create a signature for the text.
    # <i>plain</i> is a data object which contains the text.
    # <i>sig</i> is a data object where the generated signature is stored.
    def sign(plain, sig = Data.new, mode = GPGME::SIG_MODE_NORMAL)
      err = GPGME::gpgme_op_sign(self, plain, sig, mode)
      exc = GPGME::error_to_exception(err)
      raise exc if exc
      sig
    end

    def sign_result
      GPGME::gpgme_sign_result(self)
    end

    # Encrypt the plaintext in the data object for the recipients and
    # return the ciphertext.
    def encrypt(recp, plain, cipher = Data.new, flags = 0)
      err = GPGME::gpgme_op_encrypt(self, recp, flags, plain, cipher)
      exc = GPGME::error_to_exception(err)
      raise exc if exc
      cipher
    end

    def encrypt_result
      GPGME::gpgme_encrypt_result(self)
    end

    def encrypt_sign(recp, plain, cipher = Data.new, flags = 0)
      err = GPGME::gpgme_op_encrypt_sign(self, recp, flags, plain, cipher)
      exc = GPGME::error_to_exception(err)
      raise exc if exc
      cipher
    end
  end

  # A public or secret key.
  class Key
    private_class_method :new

    attr_reader :keylist_mode, :protocol, :owner_trust
    attr_reader :issuer_serial, :issuer_name, :chain_id
    attr_reader :subkeys, :uids

    def trust
      return :revoked if @revoked == 1
      return :expired if @expired == 1
      return :disabled if @disabled == 1
      return :invalid if @invalid == 1
    end

    def capability
      caps = Array.new
      caps << :encrypt if @can_encrypt
      caps << :sign if @can_sign
      caps << :certify if @can_certify
      caps << :authenticate if @can_authenticate
      caps
    end

    def secret?
      @secret == 1
    end

    def inspect
      primary_subkey = subkeys[0]
      sprintf("#<#{self.class} %s %4d%c/%s %s trust=%s, owner_trust=%s, \
capability=%s, subkeys=%s, uids=%s>",
              primary_subkey.secret? ? 'sec' : 'pub',
              primary_subkey.length,
              primary_subkey.pubkey_algo_letter,
              primary_subkey.fingerprint[-8 .. -1],
              primary_subkey.timestamp.strftime('%Y-%m-%d'),
              trust.inspect,
              VALIDITY_NAMES[@owner_trust].inspect,
              capability.inspect,
              subkeys.inspect,
              uids.inspect)
    end

    def to_s
      primary_subkey = subkeys[0]
      s = sprintf("%s   %4d%c/%s %s\n",
                  primary_subkey.secret? ? 'sec' : 'pub',
                  primary_subkey.length,
                  primary_subkey.pubkey_algo_letter,
                  primary_subkey.fingerprint[-8 .. -1],
                  primary_subkey.timestamp.strftime('%Y-%m-%d'))
      uids.each do |user_id|
        s << "uid\t\t#{user_id.name} <#{user_id.email}>\n"
      end
      subkeys.each do |subkey|
        s << subkey.to_s
      end
      s
    end
  end

  class SubKey
    private_class_method :new

    attr_reader :pubkey_algo, :length, :keyid, :fpr
    alias fingerprint fpr

    def trust
      return :revoked if @revoked == 1
      return :expired if @expired == 1
      return :disabled if @disabled == 1
      return :invalid if @invalid == 1
    end

    def capability
      caps = Array.new
      caps << :encrypt if @can_encrypt
      caps << :sign if @can_sign
      caps << :certify if @can_certify
      caps << :authenticate if @can_authenticate
      caps
    end

    def secret?
      @secret == 1
    end

    def timestamp
      Time.at(@timestamp)
    end

    def expires
      Time.at(@expires)
    end

    PUBKEY_ALGO_LETTERS = {
      PK_RSA => ?R,
      PK_ELG_E => ?g,
      PK_ELG => ?G,
      PK_DSA => ?D
    }

    def pubkey_algo_letter
      PUBKEY_ALGO_LETTERS[@pubkey_algo] || ??
    end

    def inspect
      sprintf("#<#{self.class} %s %4d%c/%s %s trust=%s, capability=%s>",
              secret? ? 'ssc' : 'sub',
              length,
              pubkey_algo_letter,
              (@fingerprint || @keyid)[-8 .. -1],
              timestamp.strftime('%Y-%m-%d'),
              trust.inspect,
              capability.inspect)
    end

    def to_s
      sprintf("%s   %4d%c/%s %s\n",
              secret? ? 'ssc' : 'sub',
              length,
              pubkey_algo_letter,
              (@fingerprint || @keyid)[-8 .. -1],
              timestamp.strftime('%Y-%m-%d'))
    end
  end

  class UserID
    private_class_method :new

    attr_reader :validity, :uid, :name, :comment, :email, :signatures

    def revoked?
      @revoked == 1
    end

    def invalid?
      @invalid == 1
    end

    def inspect
      "#<#{self.class} #{name} <#{email}> \
validity=#{VALIDITY_NAMES[validity]}, signatures=#{signatures.inspect}>"
    end
  end

  class KeySig
    private_class_method :new

    attr_reader :pubkey_algo, :keyid

    def revoked?
      @revoked == 1
    end

    def expired?
      @expired == 1
    end

    def invalid?
      @invalid == 1
    end

    def exportable?
      @exportable == 1
    end

    def timestamp
      Time.at(@timestamp)
    end

    def expires
      Time.at(@expires)
    end

    def inspect
      "#<#{self.class} #{keyid} timestamp=#{timestamp}, expires=#{expires}>"
    end
  end

  class VerifyResult
    private_class_method :new

    attr_reader :signatures
  end

  class Signature
    private_class_method :new

    attr_reader :summary, :fpr, :status, :notations
    alias fingerprint fpr

    def timestamp
      Time.at(@timestamp)
    end

    def exp_timestamp
      Time.at(@exp_timestamp)
    end

    def to_s
      ctx = Ctx.new
      if from_key = ctx.get_key(fingerprint)
        from = "#{from_key.subkeys[0].keyid} #{from_key.uids[0].uid}"
      else
        from = fingerprint
      end
      case GPGME::gpgme_err_code(status)
      when GPGME::GPG_ERR_NO_ERROR
	"Good signature from #{from}"
      when GPGME::GPG_ERR_SIG_EXPIRED
	"Expired signature from #{from}"
      when GPGME::GPG_ERR_KEY_EXPIRED
	"Signature made from expired key #{from}"
      when GPGME::GPG_ERR_CERT_REVOKED
	"Signature made from revoked key #{from}"
      when GPGME::GPG_ERR_BAD_SIGNATURE
	"Bad signature from #{from}"
      when GPGME::GPG_ERR_NO_ERROR
	"No public key for #{from}"
      end
    end
  end

  class DecryptResult
    private_class_method :new

    attr_reader :unsupported_algorithm, :wrong_key_usage
  end

  class SignResult
    private_class_method :new

    attr_reader :invalid_signers, :signatures
  end

  class EncryptResult
    private_class_method :new

    attr_reader :invalid_recipients
  end

  class InvalidKey
    private_class_method :new

    attr_reader :fpr, :reason
    alias fingerprint fpr
  end

  class NewSignature
    private_class_method :new

    attr_reader :type, :pubkey_algo, :hash_algo, :sig_class, :fpr
    alias fingerprint fpr

    def timestamp
      Time.at(@timestamp)
    end
  end

  class ImportStatus
    private_class_method :new

    attr_reader :fpr, :result, :status
    alias fingerprint fpr
  end

  class ImportResult
    private_class_method :new

    attr_reader :considered, :no_user_id, :imported, :imported_rsa, :unchanged
    attr_reader :new_user_ids, :new_sub_keys, :new_signatures, :new_revocations
    attr_reader :secret_read, :secret_imported, :secret_unchanged
    attr_reader :not_imported, :imports
  end
end
