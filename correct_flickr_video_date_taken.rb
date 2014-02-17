#! ruby -EWindows-31J
# -*- mode:ruby; coding:Windows-31J -*-

#(特にEye-Fiが)flickrにアップロードした動画ファイルのdate taken(撮影日時)が
#正しく設定されずアップロード日時になってしまう問題を修正するツール

#flickrの同名タイトル・同じ長さの動画ファイルのdate takenにローカルファイルの更新日時を書き込む
#ファイル名と同じタイトルがflickrのコンテンツに付与されていることが前提

#date takenに更新日時を書き込む条件
#ローカルファイルが動画系拡張子
#flickrのtitleとローカルファイルのファイル名（拡張子付きか拡張子なしのどちらか）が一致する
#flickrのコンテンツ種別が動画(video)である
#動画の長さ(秒単位)が一致している
#date takenとローカル更新日時が異なる

#検索対象のディレクトリは、
#引数なしなら実行スクリプトのあるディレクトリ
#ディレクトリパスの引数があればそこが対象。複数引数があればすべて対象。
#引数のパス区切り文字は、/も、dosishな\も、両対応

#todo?
#○ファイル名ヒット確認時の拡張子有無対応
#×jpegファイルをリストから除外して高速化→videosの数の食い違いが発生し、gop動画問題に気づいた。
#gop動画も動画に入れると高速化効果がなくなるのでjpegファイルを除外するのはあきらめた
#キャッシュ対応
#前回から不変のセットの場合はキャッシュを使う
#前回実行時から不変のセットに対し、処理したことのあるローカルファイルはスキップ
#まだ処理したことのないローカルファイルは全flickrに対して処理
#png対応
#eye-fiはpngを作らない。pngがflickrに送られる機会のほとんどはiOSなどスマホ系から。
#まあ、PCのスクリーンショットをflickrに送る人もいるだろう。
#コマンドラインオプション
#gui対応
#動画ファイルのメタデータを見る
#タイムゾーン対応（更新日時のタイムゾーンとOSのタイムゾーンの一致確認）

require 'pp'
#require 'rubygems'

require 'flickraw'
require 'win32ole'
require_relative 'webbrowser'
require_relative 'crypt'

class MyFlickr < FlickRaw::Flickr

    #このアプリのIDに相当するもの。
    API_KEY='721140cc23692fb1ed689e42a185b4b2'

    #このアプリであることを証明するパスワード。建前としては秘密だがデスクトップアプリで秘密を守るのは困難。
    SHARED_SECRET='cfdd0e16cbe6c03f'

    #access_tokenとaccess_secretは暗号化してローカルにファイルを作る
    ACCESS_TOKEN_FILE='tok.enc'
    ACCESS_SECRET_FILE='sec.enc'

    #対象とする拡張子。flickrが読み込む動画拡張子（ちゃんと網羅はされてない。適当）。いずれPNGもdate taken設定できるといいかも。
    EXT_LIST='avi,wmv,mov,mpeg,mpg,m4v,mp4,3gp,m2ts,mts,ogg,ogv'

    def initialize
        FlickRaw.api_key = API_KEY
        FlickRaw.shared_secret = SHARED_SECRET

        token, secret = flickr_authorize
        @flickr = FlickRaw::Flickr.new
        @flickr.access_token = token
        @flickr.access_secret = secret
        puts "You are now authenticated flickr as :" + @flickr.test.login.username
    end

    def flickr_authorize
        if File.exist?(ACCESS_TOKEN_FILE) && File.exist?(ACCESS_SECRET_FILE)
            #ファイルから読み込み
            access_token = decrypt_read(ACCESS_TOKEN_FILE)
            access_secret = decrypt_read(ACCESS_SECRET_FILE)
        else
            #オーソリを行いトークンとシークレットを暗号化してファイルに書く
            token = flickr.get_request_token
            auth_url = flickr.get_authorize_url(token['oauth_token'], :perms => 'delete')

            puts "Open this url in your process to complete the authication process : #{auth_url}"
            WebBrowser.open auth_url
            puts "Copy here the number given when you complete the process."
            verify = $stdin.gets.strip
 
            begin
                flickr.get_access_token(token['oauth_token'], token['oauth_token_secret'], verify)
                access_token = flickr.access_token
                access_secret = flickr.access_secret
                encrypt_write(ACCESS_TOKEN_FILE, access_token)
                encrypt_write(ACCESS_SECRET_FILE, access_secret)
            rescue FlickRaw::FailedResponse => e
                puts "Authentication failed : #{e.msg}"
            end
        end
        return access_token, access_secret
    end

    def decrypt_read(fname)
        io = File.open(fname, "rb")
        raw_data = io.read
        data = decrypt_data(raw_data[16, raw_data.size], SHARED_SECRET, raw_data[8, 8])
        io.close
        return data
    end

    def encrypt_write(fname, data)
        io = File.open(fname, "wb")
        salt = OpenSSL::Random.random_bytes(8)
        io.write "Salted__" + salt + encrypt_data(data, SHARED_SECRET, salt)
        io.close
    end

    def local_list_file
            #更新日時の参照元となる動画が入ったローカルフォルダ。サブディレクトリも見に行く。
            if ARGV.size == 0
                dirglob = local_glob_files(File.expand_path(File.dirname(__FILE__)))
            else
                dirglob = []
                ARGV.each do |arg|
                    unless File.directory?(arg)
                        puts arg + " is not a directory."
                        next
                    end
                    one_dirglob = local_glob_files(arg.gsub(File::ALT_SEPARATOR) {File::SEPARATOR})
                    puts one_dirglob.size.to_s + " file(s) found."
                    dirglob = dirglob + one_dirglob
                end
            end

            if dirglob.size == 0
                puts "total " + dirglob.size.to_s + " file(s) found."
                puts "do nothing."
                puts "usage: video_taken_date_fixr.rb [media_path1] [media_path2]..."
                exit
            else
                puts "total " + dirglob.size.to_s + " file(s) found."
                before = dirglob.size
                dirglob.uniq!
                after = dirglob.size
                puts (before - after).to_s + " duplicate file(s) excluded." if after < before
            end
        return dirglob
    end

    def local_glob_files(search_path)
        puts "Search Path:" + search_path
        dirglob = Dir.glob("#{search_path}/**/*.{#{EXT_LIST}}".encode('utf-8'))
        dirglob.each{|f|
            puts f
        }
        return dirglob
    end

    def flickr_set2list(photo_set)
        #set内のコンテンツをリスト化する
            #set情報にdate_updateという項目がある。
            #出力を保存しておき、date_updateが更新されてないならキャッシュを使う、という動作にすればよりインテリジェントになる。
            contents_num = photo_set.photos.to_i + photo_set.videos.to_i
            #contents_num = photo_set.videos.to_i

            #ページ数を調べる
            photo_list = @flickr.photosets.getPhotos :photoset_id => photo_set.id
            photo_pages=photo_list['pages'].to_i
            all_photo_list = flickr_build_photo_list(photo_set.title, photo_list, photo_pages, photo_set.id)

            #指定セット内の全写真動画リストの数。
            #セットの情報と一致しているか確認
            #flickrの挙動（バグ？）として、一致していない状態が発生しうる。修正を試みる。
            if contents_num == all_photo_list.size
                puts all_photo_list.size.to_s + " item(s) found."
            else
                puts "set info num:" + contents_num.to_s + " count num:" + all_photo_list.size.to_s
                puts "set contents number mismatch, correct start"
                #セット内写真の再整列でどうか→有効！！！　先頭一枚を同じ位置に設定するだけでいい
                @flickr.photosets.reorderPhotos :photoset_id => photo_set.id, :photo_ids => all_photo_list[0].id
                contents_num = photo_set.photos.to_i + photo_set.videos.to_i
                #contents_num = photo_set.videos.to_i
                puts "corrected set info num:" + contents_num.to_s + " count num:" + all_photo_list.size.to_s
            end
            #食い違いを修正するコードが入ったので、今後ここで止まるならなにか未知の理由。
            #raise "photos and videos number mismatch" unless contents_num == all_photo_list.size
        return all_photo_list
    end

    def flickr_build_photo_list(set_name, photo_list, photo_pages, id)
        puts
        puts "flickr Set Name:" + set_name
        all_contents_list = []
        #all_photo_list = []
        #all_video_list = []
        1.upto(photo_pages) do |i|
            #page数
            puts "Page " + i.to_s
            if set_name == "Not In Set"
                all_list = @flickr.photos.getNotInSet :page => i
                #photo_list = @flickr.photos.getNotInSet :page => i, :media => 'photos'
                #video_list = @flickr.photos.getNotInSet :page => i, :media => 'videos'
            else
                all_list = @flickr.photosets.getPhotos :photoset_id => id, :page => i
                #photo_list = @flickr.photosets.getPhotos :photoset_id => id, :page => i, :media => 'photos'
                #video_list = @flickr.photosets.getPhotos :photoset_id => id, :page => i, :media => 'videos'
            end
            all_contents_list = all_contents_list + all_list['photo']
            #all_photo_list = all_photo_list + photo_list['photo']
            #all_video_list = all_video_list + video_list['photo']
        end

        return all_contents_list
    end

    def search_and_fix(dirglob, all_photo_list)
        shell = WIN32OLE.new('Shell.Application')
        dirglob.each{|f|
            #Eye-Fiアップロードの場合はtitleに拡張子が付くので拡張子付きファイル名で検索している
            fname=File.basename(f) #,'.*'を付ければ拡張子を除ける
            fname_noext=File.basename(f,'.*')
            #ext=File.extname(f)

            #ローカル動画ファイルのファイル名
            #puts fname

            #パスのセパレータを/から\に置換する必要がある
            dname=File.dirname(f).gsub(/\//) {"\\"}

            #ローカル動画ファイルの長さ
            unless dur=shell.NameSpace(dname).ParseName(fname).ExtendedProperty("Duration") then next end

            #動画でないならnilが返ってくる。念のためこれも判定に使う。
            unless shell.NameSpace(dname).ParseName(fname).ExtendedProperty("Frame Rate") then next end

            #p shell.NameSpace(dname).ParseName(fname).ExtendedProperty("Type")
            micro_sec = 10**7
            dur_sec= (dur.to_f/micro_sec).round
            #p dur_sec

            #ローカルファイルの更新日時 タイムゾーンは付けない
            modtime=File.mtime(f).strftime("%Y-%m-%d %H:%M:%S")
            #p modtime

            #if modtime.to_s.length == 25 #タイムゾーン付き表記と判断 ex."2014-01-02 15:07:02 +0900"
            #    #before_timezone_pos=-7
            #    modtime.to_s.sub!(/ [+-]\d\d\d\d$/, "") #タイムゾーン部分を削除
            #end
            #puts "writing time:" + modtime_notz

            #titleを検索ワードにしてflickrの検索を使っても全然ヒットせず使えない
            #list = @flickr.photos.search(:user_id => 'me', :text => fname)

            #拡張子ありのタイトルと拡張子無しのタイトルに両対応。
            flickr_hit_list = all_photo_list.select{|x| (x.title == fname || x.title == fname_noext)}
            #複数ヒットの場合スキップしてログ出力するとかならここで分岐せよ
            #現状の挙動は複数ヒットの場合すべて処理

            #名前が一致した全写真に対して処理
            change_date_taken(flickr_hit_list, dur_sec, modtime)
        }
    end

    def change_date_taken(flickr_hit_list, dur_sec, modtime_notz)
        flickr_hit_list.each do |photo|
            #p photo
            info = @flickr.photos.getInfo :photo_id => photo.id
            #pp info
            #p info.video.duration
            #p info.dates.taken
            puts "check flickr:"+ info.title

            #最終目的であるdate takenへの更新日付の書き込みをここで行う
            #長さが同じ、かつ日付がローカルと違うなら書き込む
            #既にローカル更新日付が書き込まれている場合は上書きしない
            if info.media == "video" && dur_sec == info.video.duration.to_i && modtime_notz != info.dates.taken
                puts "overwrite taken date to flickr [" + info.title + "] new:" + modtime_notz + " --> old:" + info.dates.taken
                @flickr.photos.setDates :photo_id => photo.id, :date_taken => modtime_notz
            end
        end
    end

    def fixTakenDate
        begin
            dirglob = local_list_file

            #全セットでループを回す
            @flickr.photosets.getList.each do |photo_set|
                all_photo_list = flickr_set2list(photo_set)
                search_and_fix(dirglob, all_photo_list)
            end

            #セットに入っていないコンテンツはここで
            photo_list = @flickr.photos.getNotInSet :page => 1
            photo_pages = photo_list.pages.to_i
            all_photo_list = flickr_build_photo_list("Not In Set", photo_list, photo_pages, 0)

            puts all_photo_list.size.to_s + " item(s) found."
            search_and_fix(dirglob, all_photo_list)
        rescue => ex
            puts "#{Time.now} error raised"
            puts ex.message
        end
    end
end

if __FILE__ == $0
    myflickr = MyFlickr.new
    myflickr.fixTakenDate
end
