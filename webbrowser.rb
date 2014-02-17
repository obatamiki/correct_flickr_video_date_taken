#! ruby -EWindows-31J
# -*- mode:ruby; coding:Windows-31J -*-

require 'uri'

class WebBrowser
  def self.open(uri)
    uri = URI.parse(uri.to_s)
    unless %w[ http https ftp file ].include?(uri.scheme)
      raise ArgumentError
    end
    case RUBY_PLATFORM
    when /mswin(?!ce)|mingw|bccwin/
      #system %!start /B #{uri}!
      #&を含むuriをコマンドプロンプトに正しく渡すため&を^でエスケープ
      str = %!start /B #{uri}!
      str.gsub!(/&/) {'^&'}
      system str
    when /cygwin/
      system %!cmd /C start /B #{uri}!
    when /darwin/
      system %!open '#{uri}'!
    when /linux/
      system %!xdg-open '#{uri}'!
    when /java/
      require 'java'
      import 'java.awt.Desktop'
      import 'java.net.URI'
      Desktop.getDesktop.browse java.net.URI.new(uri)
    else
      raise NotImplementedError
    end
  end
end
