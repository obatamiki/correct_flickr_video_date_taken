#! ruby -EWindows-31J
# -*- mode:ruby; coding:Windows-31J -*-

#(����Eye-Fi��)flickr�ɃA�b�v���[�h��������t�@�C����date taken(�B�e����)��
#�������ݒ肳�ꂸ�A�b�v���[�h�����ɂȂ��Ă��܂������C������c�[��

#flickr�̓����^�C�g���E���������̓���t�@�C����date taken�Ƀ��[�J���t�@�C���̍X�V��������������
#�t�@�C�����Ɠ����^�C�g����flickr�̃R���e���c�ɕt�^����Ă��邱�Ƃ��O��

#date taken�ɍX�V�������������ޏ���
#���[�J���t�@�C��������n�g���q
#flickr��title�ƃ��[�J���t�@�C���̃t�@�C�����i�g���q�t�����g���q�Ȃ��̂ǂ��炩�j����v����
#flickr�̃R���e���c��ʂ�����(video)�ł���
#����̒���(�b�P��)����v���Ă���
#date taken�ƃ��[�J���X�V�������قȂ�

#�����Ώۂ̃f�B���N�g���́A
#�����Ȃ��Ȃ���s�X�N���v�g�̂���f�B���N�g��
#�f�B���N�g���p�X�̈���������΂������ΏہB��������������΂��ׂđΏہB
#�����̃p�X��؂蕶���́A/���Adosish��\���A���Ή�

#todo?
#���t�@�C�����q�b�g�m�F���̊g���q�L���Ή�
#�~jpeg�t�@�C�������X�g���珜�O���č�������videos�̐��̐H���Ⴂ���������Agop������ɋC�Â����B
#gop���������ɓ����ƍ��������ʂ��Ȃ��Ȃ�̂�jpeg�t�@�C�������O����̂͂�����߂�
#�L���b�V���Ή�
#�O�񂩂�s�ς̃Z�b�g�̏ꍇ�̓L���b�V�����g��
#�O����s������s�ς̃Z�b�g�ɑ΂��A�����������Ƃ̂��郍�[�J���t�@�C���̓X�L�b�v
#�܂������������Ƃ̂Ȃ����[�J���t�@�C���͑Sflickr�ɑ΂��ď���
#png�Ή�
#eye-fi��png�����Ȃ��Bpng��flickr�ɑ�����@��̂قƂ�ǂ�iOS�ȂǃX�}�z�n����B
#�܂��APC�̃X�N���[���V���b�g��flickr�ɑ���l�����邾�낤�B
#�R�}���h���C���I�v�V����
#gui�Ή�
#����t�@�C���̃��^�f�[�^������
#�^�C���]�[���Ή��i�X�V�����̃^�C���]�[����OS�̃^�C���]�[���̈�v�m�F�j

require 'pp'
#require 'rubygems'

require 'flickraw'
require 'win32ole'
require_relative 'webbrowser'
require_relative 'crypt'

class MyFlickr < FlickRaw::Flickr

    #���̃A�v����ID�ɑ���������́B
    API_KEY='721140cc23692fb1ed689e42a185b4b2'

    #���̃A�v���ł��邱�Ƃ��ؖ�����p�X���[�h�B���O�Ƃ��Ă͔閧�����f�X�N�g�b�v�A�v���Ŕ閧�����͍̂���B
    SHARED_SECRET='cfdd0e16cbe6c03f'

    #access_token��access_secret�͈Í������ă��[�J���Ƀt�@�C�������
    ACCESS_TOKEN_FILE='tok.enc'
    ACCESS_SECRET_FILE='sec.enc'

    #�ΏۂƂ���g���q�Bflickr���ǂݍ��ޓ���g���q�i�����Ɩԗ��͂���ĂȂ��B�K���j�B������PNG��date taken�ݒ�ł���Ƃ��������B
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
            #�t�@�C������ǂݍ���
            access_token = decrypt_read(ACCESS_TOKEN_FILE)
            access_secret = decrypt_read(ACCESS_SECRET_FILE)
        else
            #�I�[�\�����s���g�[�N���ƃV�[�N���b�g���Í������ăt�@�C���ɏ���
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
            #�X�V�����̎Q�ƌ��ƂȂ铮�悪���������[�J���t�H���_�B�T�u�f�B���N�g�������ɍs���B
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
        #set���̃R���e���c�����X�g������
            #set����date_update�Ƃ������ڂ�����B
            #�o�͂�ۑ����Ă����Adate_update���X�V����ĂȂ��Ȃ�L���b�V�����g���A�Ƃ�������ɂ���΂��C���e���W�F���g�ɂȂ�B
            contents_num = photo_set.photos.to_i + photo_set.videos.to_i
            #contents_num = photo_set.videos.to_i

            #�y�[�W���𒲂ׂ�
            photo_list = @flickr.photosets.getPhotos :photoset_id => photo_set.id
            photo_pages=photo_list['pages'].to_i
            all_photo_list = flickr_build_photo_list(photo_set.title, photo_list, photo_pages, photo_set.id)

            #�w��Z�b�g���̑S�ʐ^���惊�X�g�̐��B
            #�Z�b�g�̏��ƈ�v���Ă��邩�m�F
            #flickr�̋����i�o�O�H�j�Ƃ��āA��v���Ă��Ȃ���Ԃ�����������B�C�������݂�B
            if contents_num == all_photo_list.size
                puts all_photo_list.size.to_s + " item(s) found."
            else
                puts "set info num:" + contents_num.to_s + " count num:" + all_photo_list.size.to_s
                puts "set contents number mismatch, correct start"
                #�Z�b�g���ʐ^�̍Đ���łǂ������L���I�I�I�@�擪�ꖇ�𓯂��ʒu�ɐݒ肷�邾���ł���
                @flickr.photosets.reorderPhotos :photoset_id => photo_set.id, :photo_ids => all_photo_list[0].id
                contents_num = photo_set.photos.to_i + photo_set.videos.to_i
                #contents_num = photo_set.videos.to_i
                puts "corrected set info num:" + contents_num.to_s + " count num:" + all_photo_list.size.to_s
            end
            #�H���Ⴂ���C������R�[�h���������̂ŁA���ケ���Ŏ~�܂�Ȃ�Ȃɂ����m�̗��R�B
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
            #page��
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
            #Eye-Fi�A�b�v���[�h�̏ꍇ��title�Ɋg���q���t���̂Ŋg���q�t���t�@�C�����Ō������Ă���
            fname=File.basename(f) #,'.*'��t����Ίg���q��������
            fname_noext=File.basename(f,'.*')
            #ext=File.extname(f)

            #���[�J������t�@�C���̃t�@�C����
            #puts fname

            #�p�X�̃Z�p���[�^��/����\�ɒu������K�v������
            dname=File.dirname(f).gsub(/\//) {"\\"}

            #���[�J������t�@�C���̒���
            unless dur=shell.NameSpace(dname).ParseName(fname).ExtendedProperty("Duration") then next end

            #����łȂ��Ȃ�nil���Ԃ��Ă���B�O�̂��߂��������Ɏg���B
            unless shell.NameSpace(dname).ParseName(fname).ExtendedProperty("Frame Rate") then next end

            #p shell.NameSpace(dname).ParseName(fname).ExtendedProperty("Type")
            micro_sec = 10**7
            dur_sec= (dur.to_f/micro_sec).round
            #p dur_sec

            #���[�J���t�@�C���̍X�V���� �^�C���]�[���͕t���Ȃ�
            modtime=File.mtime(f).strftime("%Y-%m-%d %H:%M:%S")
            #p modtime

            #if modtime.to_s.length == 25 #�^�C���]�[���t���\�L�Ɣ��f ex."2014-01-02 15:07:02 +0900"
            #    #before_timezone_pos=-7
            #    modtime.to_s.sub!(/ [+-]\d\d\d\d$/, "") #�^�C���]�[���������폜
            #end
            #puts "writing time:" + modtime_notz

            #title���������[�h�ɂ���flickr�̌������g���Ă��S�R�q�b�g�����g���Ȃ�
            #list = @flickr.photos.search(:user_id => 'me', :text => fname)

            #�g���q����̃^�C�g���Ɗg���q�����̃^�C�g���ɗ��Ή��B
            flickr_hit_list = all_photo_list.select{|x| (x.title == fname || x.title == fname_noext)}
            #�����q�b�g�̏ꍇ�X�L�b�v���ă��O�o�͂���Ƃ��Ȃ炱���ŕ��򂹂�
            #����̋����͕����q�b�g�̏ꍇ���ׂď���

            #���O����v�����S�ʐ^�ɑ΂��ď���
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

            #�ŏI�ړI�ł���date taken�ւ̍X�V���t�̏������݂������ōs��
            #�����������A�����t�����[�J���ƈႤ�Ȃ珑������
            #���Ƀ��[�J���X�V���t���������܂�Ă���ꍇ�͏㏑�����Ȃ�
            if info.media == "video" && dur_sec == info.video.duration.to_i && modtime_notz != info.dates.taken
                puts "overwrite taken date to flickr [" + info.title + "] new:" + modtime_notz + " --> old:" + info.dates.taken
                @flickr.photos.setDates :photo_id => photo.id, :date_taken => modtime_notz
            end
        end
    end

    def fixTakenDate
        begin
            dirglob = local_list_file

            #�S�Z�b�g�Ń��[�v����
            @flickr.photosets.getList.each do |photo_set|
                all_photo_list = flickr_set2list(photo_set)
                search_and_fix(dirglob, all_photo_list)
            end

            #�Z�b�g�ɓ����Ă��Ȃ��R���e���c�͂�����
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
