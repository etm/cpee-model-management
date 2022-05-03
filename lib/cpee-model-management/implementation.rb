#!/usr/bin/ruby
#
# This file is part of CPEE-MODEL-MANAGEMENT
#
# CPEE-MODEL-MANAGEMENT is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# CPEE-MODEL-MANAGEMENT is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# CPEE-MODEL-MANAGEMENT (file LICENSE in the main directory). If not, see
# <http://www.gnu.org/licenses/>.

require 'rubygems'
require 'json'
require 'riddl/server'
require 'riddl/client'
require 'riddl/protocols/utils'
require 'fileutils'
require 'pathname'
require 'shellwords'
require 'securerandom'
require 'cpee/redis'

module CPEE
  module ModelManagement

    SERVER = File.expand_path(File.join(__dir__,'moma.xml'))

    def self::git_mv(models,old,new)
      cdir = Dir.pwd
      Dir.chdir(File.join(models,File.dirname(old)))
      p1 = Pathname.new(File.dirname(old))
      p2 = Pathname.new(File.dirname(new))
      told = File.basename(old)
      tnew = File.join(p1.relative_path_from(p1).to_s,File.basename(new))
      `git -c user.name='Christine Ashcreek' -c user.email=dev@null.com -c push.default=simple mv     "#{told}"                      "#{tnew}"            2>/dev/null`
      `git -c user.name='Christine Ashcreek' -c user.email=dev@null.com -c push.default=simple rm -rf "#{told + '.active'}"                               2>/dev/null`
      `git -c user.name='Christine Ashcreek' -c user.email=dev@null.com -c push.default=simple rm -rf "#{told + '.active-uuid'}"                          2>/dev/null`
      `git -c user.name='Christine Ashcreek' -c user.email=dev@null.com -c push.default=simple mv     "#{told + '.attrs'}"          "#{tnew + '.attrs'}"  2>/dev/null`
      Dir.chdir(cdir)
      CPEE::ModelManagement::fs_mv(models,old,new) # fallback
    end
    def self::git_rm(models,new)
      cdir = Dir.pwd
      Dir.chdir(File.join(models,File.dirname(new)))
      tnew = File.basename(new)
      `git -c user.name='Christine Ashcreek' -c user.email=dev@null.com -c push.default=simple rm -rf "#{tnew}" 2>/dev/null`
       FileUtils.rm_rf(tnew)
      `git -c user.name='Christine Ashcreek' -c user.email=dev@null.com -c push.default=simple rm -rf "#{tnew}.active"      2>/dev/null`
      `git -c user.name='Christine Ashcreek' -c user.email=dev@null.com -c push.default=simple rm -rf "#{tnew}.active-uuid" 2>/dev/null`
      `git -c user.name='Christine Ashcreek' -c user.email=dev@null.com -c push.default=simple rm -rf "#{tnew}.attrs"      2>/dev/null`
      Dir.chdir(cdir)
      CPEE::ModelManagement::fs_rm(models,new) # fallback
    end
    def self::git_shift(models,new)
      cdir = Dir.pwd
      Dir.chdir(File.join(models,File.dirname(new)))
      nnew = File.basename(new)
      `git -c user.name='Christine Ashcreek' -c user.email=dev@null.com -c push.default=simple rm -rf "#{nnew}.active"      2>/dev/null`
      `git -c user.name='Christine Ashcreek' -c user.email=dev@null.com -c push.default=simple rm -rf "#{nnew}.active-uuid" 2>/dev/null`
      Dir.chdir(cdir)
      CPEE::ModelManagement::fs_shift(models,new) # fallback
    end
    def self::git_commit(models,new,author)
      rp = File.realpath(models)
      crb = File.join(__dir__,'commit.rb')
      system 'ruby ' + crb + ' ' + [rp, new, author].shelljoin + ' &'
    end
    def self::fs_mv(models,old,new)
      fname = File.join(models,old)
      fnname = File.join(models,new)
      FileUtils.mv(fname,fnname) rescue nil
      File.delete(fname + '.active',fnname + '.active') rescue nil
      File.delete(fname + '.active-uuid',fnname + '.active-uuid') rescue nil
      FileUtils.mv(fname + '.attrs',fnname + '.attrs') rescue nil
    end
    def self::fs_cp(models,old,new)
      fname = File.join(models,old)
      fnname = File.join(models,new)
      FileUtils.cp(fname,fnname)
      File.delete(fname + '.active',fnname + '.active') rescue nil
      File.delete(fname + '.active-uuid',fnname + '.active-uuid') rescue nil
      FileUtils.cp(fname + '.attrs',fnname + '.attrs') rescue nil
    end
    def self::fs_rm(models,new)
      fname = File.join(models,new)
      FileUtils.rm_rf(fname)
      File.delete(fname + '.active') rescue nil
      File.delete(fname + '.active-uuid') rescue nil
      File.delete(fname + '.attrs') rescue nil
    end
    def self::fs_shift(models,new)
      fname = File.join(models,new)
      File.delete(fname + '.active') rescue nil
      File.delete(fname + '.active-uuid') rescue nil
    end

    def self::git_dir(models,file)
      return nil if file.nil?
      cdir = Dir.pwd
      tdir = File.dirname(file)
      Dir.chdir(File.join(models,tdir))
      res = `git rev-parse --absolute-git-dir 2>/dev/null`
      Dir.chdir(cdir)
      res == '' ? nil : res
    end

    def self::op(author,op,models,new,old=nil) #{{{
      git_ndir = CPEE::ModelManagement::git_dir(models,new)
      git_odir = CPEE::ModelManagement::git_dir(models,old)

      if op == 'rm' && !git_ndir.nil?
        git_rm models, new
        git_commit models, new, author
      elsif op == 'shift' && !git_ndir.nil?
        git_shift models, new
        git_commit models, new, author
      elsif op == 'mv' && (!git_ndir.nil? || !git_odir.nil?)
        if git_ndir == git_odir
          git_mv models, old, new
          git_commit models, new, author
        elsif git_ndir != git_odir && !git_ndir.nil? && !git_odir.nil?
          fs_cp models, old, new
          git_rm models, old
          git_commit models, old, author
          git_commit models, new, author
        elsif git_ndir != git_odir && git_ndir.nil?
          fs_cp models, old, new
          git_rm models, old
          git_commit models, old, author
        elsif git_ndir != git_odir && git_odir.nil?
          fs_mv models, old, new
          git_commit models, new, author
        end
      elsif !git_ndir.nil?
        git_commit models, new, author
      else
        case op
          when 'mv'; fs_mv(models,old,new)
          when 'rm'; fs_rm(models,new)
          when 'shift'; fs_shift(models,new)
        end
      end
    end #}}}
    def self::get_dn(dn) #{{{
      if dn
        dn.split(',').map{ |e| e.split('=',2) }.to_h
      else
        { 'GN' => 'Christine', 'SN' => 'Ashcreek' }
      end
    end #}}}
    def self::notify(conns,op,models,f,s=nil) #{{{
      what = if f =~ /\.dir$/
        if  op == 'delete'
          { :op => op, :type => :dir, :name => File.basename(f) }
        else
          attrs = JSON::load File.open(f + '.attrs')
          { :op => op, :type => :dir, :name => File.basename(f), :creator => attrs['creator'], :date => File.mtime(f).xmlschema }
        end
      else
        if  op == 'delete'
          { :op => op, :type => :file, :name => f.sub(Regexp.compile(File.join(models,'/')),'') }
        else
          attrs = JSON::load File.open(f + '.attrs')
          fstage = attrs['design_stage'] rescue 'draft'
          { :op => op, :type => :file, :name => f.sub(Regexp.compile(File.join(models,'/')),''), :creator => attrs['creator'], :author => attrs['author'], :stage => fstage, :date => File.mtime(f).xmlschema }
        end
      end
      what[:source] = s.sub(/models\//,'') unless s.nil?
      conns.each do |e|
        e.send what
      end
    end #}}}

    class GetList < Riddl::Implementation #{{{
      def response
        where = @a[0] == :main ? '' : Riddl::Protocols::Utils::unescape(@r.last)
        views = @a[1]
        models = @a[2]
        stage = [@p[0]&.value] || ['draft']
        stage << views[stage[0]] if views && views[stage[0]]

        names = Dir.glob(File.join(models,where,'*.dir')).map do |f|
          attrs = JSON::load File.open(f + '.attrs')
          { :type => :dir, :name => File.basename(f), :creator => attrs['creator'], :date => File.mtime(f).xmlschema }
        end.compact.uniq.sort_by{ |e| e[:name] } + Dir.glob(File.join(models,where,'*.xml')).map do |f|
          attrs = JSON::load File.open(f + '.attrs')
          fstage = attrs['design_stage'] rescue 'draft'
          { :type => :file, :name => File.basename(f), :creator => attrs['creator'], :author => attrs['author'], :guarded => attrs['guarded'], :guarded_id => attrs['guarded_id'], :stage => fstage, :date => File.mtime(f).xmlschema } if stage.include?(fstage)
        end.compact.uniq.sort_by{ |e| e[:name] }

        Riddl::Parameter::Complex.new('list','application/json',JSON::pretty_generate(names))
      end
    end #}}}
    class GetListFull < Riddl::Implementation #{{{
      def response
        views = @a[0]
        models = @a[1]
        stage = [@p[0]&.value] || ['draft']
        stage << views[stage[0]] if views && views[stage[0]]

        names = Dir.glob(File.join(models,'*.dir/*.xml')).map do |f|
          attrs = JSON::load File.open(f + '.attrs')
          { :type => :file, :name => File.join(File.basename(File.dirname(f)),File.basename(f)), :creator => attrs['creator'], :date => File.mtime(f).xmlschema }
        end.compact.uniq.sort_by{ |e| e[:name] } + Dir.glob(File.join(models,'*.xml')).map do |f|
          attrs = JSON::load File.open(f + '.attrs')
          fstage = attrs['design_stage'] rescue 'draft'
          { :type => :file, :name => File.basename(f), :creator => attrs['creator'], :author => attrs['author'], :guarded => attrs['guarded'], :guarded_id => attrs['guarded_id'], :stage => fstage, :date => File.mtime(f).xmlschema } if stage.include?(fstage)
        end.compact.uniq.sort_by{ |e| e[:name] }

        Riddl::Parameter::Complex.new('list','application/json',JSON::pretty_generate(names))
      end
    end #}}}
    class GetStages < Riddl::Implementation #{{{
      def response
        themes = @a[0]
        Riddl::Parameter::Complex.new('list','application/json',JSON::pretty_generate(themes&.keys || []))
      end
    end #}}}

    class ShiftItem < Riddl::Implementation #{{{
      def response
        where = @a[0] == :main ? '' : Riddl::Protocols::Utils::unescape(@r[-2])
        conns = @a[1]
        themes = @a[2]
        models = @a[3]
        name  = File.basename(@r.last,'.xml')
        nstage = @p[0].value
        fname  = File.join(models,where,name + '.xml')

        dn = CPEE::ModelManagement::get_dn @h['DN']
        author = dn['GN'] + ' ' + dn['SN']

        attrs = {}
        XML::Smart::modify(fname) do |doc|
          doc.register_namespace 'p', 'http://cpee.org/ns/properties/2.0'
          doc.find('/p:testset/p:attributes/p:author').each do |ele|
            ele.text = author
          end
          doc.find('/p:testset/p:attributes/p:design_stage').each do |ele|
            ele.text = nstage
          end
          doc.find('/p:testset/p:attributes/p:theme').each do |ele|
            ele.text = themes[nstage] || 'model'
          end
          attrs = doc.find('/p:testset/p:attributes/*').map do |e|
            [e.qname.name,e.text]
          end.to_h
        end
        File.write(fname + '.attrs',JSON::pretty_generate(attrs))

        CPEE::ModelManagement::op author, 'shift', models, File.join('.', where, name + '.xml'), File.join('.', where, name + '.xml')
        CPEE::ModelManagement::notify conns, 'shift', models, fname, fname
        nil
      end
    end #}}}

    class RenameItem < Riddl::Implementation #{{{
      def response
        where = @a[0] == :main ? '' : Riddl::Protocols::Utils::unescape(@r[-2])
        conns = @a[1]
        models = @a[2]
        name  = File.basename(@r.last,'.xml')
        nname = @p[0].value
        fname  = File.join(models,where,name + '.xml')
        fnname = File.join(models,where,nname + '.xml')
        counter = 0
        stage = 'draft'
        while File.exists?(fnname)
          counter += 1
          fnname = File.join(models,where,nname + counter.to_s + '.xml')
        end

        dn = CPEE::ModelManagement::get_dn @h['DN']
        author = dn['GN'] + ' ' + dn['SN']

        attrs = {}
        XML::Smart::modify(fname) do |doc|
          doc.register_namespace 'p', 'http://cpee.org/ns/properties/2.0'
          doc.find('/p:testset/p:attributes/p:info').each do |ele|
            ele.text = File.basename(fnname,'.xml')
          end
          doc.find('/p:testset/p:attributes/p:author').each do |ele|
            ele.text = author
          end
          attrs = doc.find('/p:testset/p:attributes/*').map do |e|
            [e.qname.name,e.text]
          end.to_h
        end
        File.write(fname + '.attrs',JSON::pretty_generate(attrs))

        CPEE::ModelManagement::op author, 'mv', models, File.join('.', where, nname + '.xml'), File.join('.', where, name + '.xml')
        CPEE::ModelManagement::notify conns, 'rename', models, fnname, fname
        nil
      end
    end #}}}
    class RenameDir < Riddl::Implementation #{{{
      def response
        conns = @a[0]
        models = @a[1]
        name  = File.basename(@r.last,'.dir')
        nname = @p[0].value
        fname  = File.join(models,name + '.dir')
        fnname = File.join(models,nname + '.dir')
        counter = 0
        while File.exists?(fnname)
          counter += 1
          fnname = File.join(models,nname + counter.to_s + '.dir')
        end

        dn = CPEE::ModelManagement::get_dn @h['DN']
        author = dn['GN'] + ' ' + dn['SN']

        attrs = JSON::load File.open(fname + '.attrs')
        attrs['author'] = author
        File.write(fname + '.attrs',JSON::pretty_generate(attrs))

        Dir.glob(File.join(fname + '/*.xml')).each do |f|
          XML::Smart::modify(f) do |doc|
            doc.register_namespace 'p', 'http://cpee.org/ns/properties/2.0'
            doc.find('/p:testset/p:attributes/p:design_dir').each do |ele|
              ele.text = nname + '.dir'
            end
            attrs = doc.find('/p:testset/p:attributes/*').map do |e|
              [e.qname.name,e.text]
            end.to_h
          end
          File.write(f + '.attrs',JSON::pretty_generate(attrs))
        end

        CPEE::ModelManagement::op author, 'mv', models, File.join(nname + '.dir'), File.join(name + '.dir')
        CPEE::ModelManagement::notify conns, 'rename', models, fnname, fname
        nil
      end
    end #}}}

    class CreateDir < Riddl::Implementation #{{{
      def response
        name = @p[0].value
        conns = @a[0]
        models = @a[1]

        fname = File.join(models,name + '.dir')
        counter = 0
        while File.exists?(fname)
          counter += 1
          fname = File.join(models,name + counter.to_s + '.dir')
        end

        dn = CPEE::ModelManagement::get_dn @h['DN']
        creator = dn['GN'] + ' ' + dn['SN']

        Dir.mkdir(fname)
        FileUtils.touch(File.join(fname,'.gitignore'))

        attrs = {}
        attrs['creator'] = creator
        attrs['author'] = creator
        File.write(fname + '.attrs',JSON::pretty_generate(attrs))

        CPEE::ModelManagement::op creator, 'add', models, name + '.dir'
        CPEE::ModelManagement::notify conns, 'create', models, fname
        nil
      end
    end #}}}
    class Create < Riddl::Implementation #{{{
      def response
        where = @a[0] == :main ? '' : Riddl::Protocols::Utils::unescape(@r.last)
        stage = if @a[1] == :cre
          @p.shift.value
        else
          nil
        end
        views = @a[2]
        conns = @a[3]
        templates = @a[4]
        models = @a[5]

        name = @p[0].value
        source = @p[1] ? File.join(models,where,@p[1].value) : (templates[stage] ? templates[stage] : 'testset.xml')
        fname = File.join(models,where,name + '.xml')

        attrs = JSON::load File.open(fname + '.attrs') rescue {}
        stage = attrs['design_stage'] if stage.nil? && attrs['design_stage']
        stage = views[stage] if views && views[stage]

        counter = 0
        while File.exists?(fname)
          counter += 1
          fname = File.join(models,where,name + counter.to_s + '.xml')
        end

        dn = CPEE::ModelManagement::get_dn @h['DN']
        creator = dn['GN'] + ' ' + dn['SN']
        FileUtils.cp(source,fname)
        attrs = {}
        XML::Smart::modify(fname) do |doc|
          doc.register_namespace 'p', 'http://cpee.org/ns/properties/2.0'
          doc.find('/p:testset/p:attributes/p:info').each do |ele|
            ele.text = File.basename(fname,'.xml')
          end
          doc.find('/p:testset/p:attributes/p:creator').each do |ele|
            ele.text = creator
          end
          doc.find('/p:testset/p:attributes/p:author').each do |ele|
            ele.text = creator
          end
          doc.find('/p:testset/p:attributes/p:design_dir').each do |ele|
            ele.text = where
          end
          doc.find('/p:testset/p:attributes/p:model_uuid').each do |ele|
            ele.text = SecureRandom.uuid
          end
          if stage
            doc.find('/p:testset/p:attributes/p:design_stage').each do |ele|
              ele.text = stage
            end
          end
          attrs = doc.find('/p:testset/p:attributes/*').map do |e|
            [e.qname.name,e.text]
          end.to_h
        end
        File.write(fname + '.attrs',JSON::pretty_generate(attrs))

        CPEE::ModelManagement::op creator, 'add', models, File.join('.', where, name + '.xml')
        CPEE::ModelManagement::notify conns, 'create', models, fname
        nil
      end
    end #}}}

    class GetItem < Riddl::Implementation #{{{
      def response
        where = @a[0] == :main ? '' : Riddl::Protocols::Utils::unescape(@r[-2])
        models = @a[1]
        name   = File.basename(@r[-1],'.xml')
        fname = File.join(models,where,name + '.xml')
        if File.exists? fname
          Riddl::Parameter::Complex.new('content','application/xml',File.read(fname))
        else
          @status = 400
        end
      end
    end #}}}
    class OpenItem < Riddl::Implementation #{{{
      def response
        where = @a[0] == :main ? '' : Riddl::Protocols::Utils::unescape(@r[-3])
        name   = File.basename(@r[-2],'.xml')
        insta  = @a[1]
        cock   = @a[2]
        views  = @a[3]
        force  = @a[4]
        models = @a[5]
        stage  = @p[0]&.value || 'draft'

        fname  = File.join(models,where,name + '.xml')

        inst = nil
        begin
          inst = if File.exists?(fname + '.active') && File.exists?(fname + '.active-uuid') && !force
            t = {
              'CPEE-INSTANCE-URL'  => File.read(fname + '.active'),
              'CPEE-INSTANCE-UUID' => File.read(fname + '.active-uuid')
            }
            status, result, headers = Riddl::Client.new(File.join(t['CPEE-INSTANCE-URL'],'properties','state')).get

            if status && status >= 200 && status < 300 && (result[0].value == 'finished' || result[0].value == 'abandoned')
              force = true
              raise
            end
            status, result, headers = Riddl::Client.new(File.join(t['CPEE-INSTANCE-URL'],'properties','attributes','uuid')).get
            if status && status >= 200 && status < 300
              t['CPEE-INSTANCE-UUID'] == result[0].value ? t : nil
            else
              nil
            end
          end || begin
            status, result, headers = Riddl::Client.new(File.join(insta,'xml')).post [
              Riddl::Parameter::Simple.new('behavior','fork_ready'),
              Riddl::Parameter::Complex.new('xml','application/xml',File.read(fname))
            ] rescue nil
            if status && status >= 200 && status < 300
              JSON::parse(result[0].value.read).tap do |t|
                File.write(File.join(fname + '.active'),t['CPEE-INSTANCE-URL'])
                File.write(File.join(fname + '.active-uuid'),t['CPEE-INSTANCE-UUID'])
              end
            else
              nil
            end
          end
        rescue
          retry
        end

        if inst.nil?
          @status = 400
          return Riddl::Parameter::Complex.new('nope','text/plain','No longer exists.')
        else
          insturl = inst['CPEE-INSTANCE-URL']
          @status = 302
          @headers << Riddl::Header.new('Location',cock[stage] + insturl)
        end
        nil
      end
    end #}}}
    class ShowUrl < Riddl::Implementation #{{{
      def response
        show = @a[0]
        @status = 302
        @headers << Riddl::Header.new('Location',show + @p.first.value)
      end
    end #}}}
    class AbandonUrl < Riddl::Implementation #{{{
      def response
        aba = @p.first.value
        res1 = Typhoeus.get(File.join(aba,'properties','state','/'))
        if res1.success?
          if res1.response_body == 'ready' || res1.response_body == 'stopped'
            Typhoeus.put(File.join(aba,'properties','state','/'), headers: {'Content-Type' => 'application/x-www-form-urlencoded'}, body: "value=abandoned")
          end
        end
        nil
      end
    end #}}}

    class MoveItem < Riddl::Implementation #{{{
      def response
        where = @a[0] == :main ? '' : Riddl::Protocols::Utils::unescape(@r[-2])
        conns = @a[1]
        models = @a[2]

        name  = File.basename(@r.last,'.xml')
        to = @p[0].value

        fname = File.join(models,where,name + '.xml')
        dn = CPEE::ModelManagement::get_dn @h['DN']
        author = dn['GN'] + ' ' + dn['SN']
        if !File.exist?(File.join(models,to,name + '.xml'))
          attrs = {}
          XML::Smart::modify(fname) do |doc|
            doc.register_namespace 'p', 'http://cpee.org/ns/properties/2.0'
            doc.find('/p:testset/p:attributes/p:design_dir').each do |ele|
              ele.text = to
            end
            attrs = doc.find('/p:testset/p:attributes/*').map do |e|
              [e.qname.name,e.text]
            end.to_h
          end
          File.write(fname + '.attrs',JSON::pretty_generate(attrs))

          CPEE::ModelManagement::op author, 'mv', models, File.join('.', to, name + '.xml'), File.join('.', where, name + '.xml')
          CPEE::ModelManagement::notify conns, 'move', models, File.join(models,to,name + '.xml'), fname
        end
      end
    end #}}}
    class PutItem < Riddl::Implementation #{{{
      def response
        where = @a[0] == :main ? '' : Riddl::Protocols::Utils::unescape(@r[-2])
        conns = @a[1]
        models = @a[2]
        name  = File.basename(@r.last,'.xml')
        cont = @p[0].value.read
        dn = CPEE::ModelManagement::get_dn @h['DN']

        fname = File.join(models,where,name + '.xml')

        if File.exists?(fname)
          author = dn['GN'] + ' ' + dn['SN']
          attrs = {}
          XML::Smart.string(cont) do |doc|
            doc.register_namespace 'p', 'http://cpee.org/ns/properties/2.0'
            doc.find('/p:testset/p:attributes/p:author').each do |ele|
              ele.text = dn['GN'] + ' ' + dn['SN']
            end
            if doc.find('/p:testset/p:attributes/p:design_stage').empty?
              doc.find('/p:testset/p:attributes').first.add('p:design_stage','draft')
            else
              doc.find('/p:testset/p:attributes/p:design_stage').each do |ele|
                ele.text = 'draft' if ele.text.strip == ''
              end
            end
            attrs = doc.find('/p:testset/p:attributes/*').map do |e|
              [e.qname.name,e.text]
            end.to_h
            File.write(fname,doc.to_s)
          end
          File.write(fname + '.attrs',JSON::pretty_generate(attrs))
          CPEE::ModelManagement::op author, 'add', models, File.join('.', where, name + '.xml')
          CPEE::ModelManagement::notify conns, 'put', models, fname
        else
          @status = 400
        end
      end
    end #}}}
    class DeleteItem < Riddl::Implementation #{{{
      def response
        where = @a[0] == :main ? '' : Riddl::Protocols::Utils::unescape(@r[-2])
        conns = @a[1]
        models = @a[2]
        name  = File.basename(@r.last,'.xml')
        fname = File.join(models,where,name + '.xml')

        dn     = CPEE::ModelManagement::get_dn @h['DN']
        author = dn['GN'] + ' ' + dn['SN']

        CPEE::ModelManagement::op author, 'rm', models, File.join('.', where, name + '.xml')
        CPEE::ModelManagement::notify conns, 'delete', models, fname
      end
    end #}}}
    class DeleteDir < Riddl::Implementation #{{{
      def response
        conns = @a[0]
        models = @a[1]
        name  = File.basename(@r.last,'.dir')
        fname = File.join(models,name + '.dir')

        dn     = CPEE::ModelManagement::get_dn @h['DN']
        author = dn['GN'] + ' ' + dn['SN']

        CPEE::ModelManagement::op author, 'rm', models, File.join(name + '.dir')
        CPEE::ModelManagement::notify conns, 'delete', models, fname
      end
    end #}}}

    class ManagementSend < Riddl::SSEImplementation #{{{
      def onopen
        @conns = @a[0]
        @conns << self
      end
      def onclose
        @conns.delete(self)
      end
    end #}}}

    class StatSend < Riddl::SSEImplementation #{{{
      def onopen
        @conns = @a[0]
        @conns << self
      end
      def onclose
        @conns.delete(self)
      end
    end #}}}

    class StatReceive < Riddl::Implementation #{{{
      def response
        redis         = @a[0]
        receivers     = @a[1]
        topic         = @p[1].value
        event_name    = @p[2].value
        notification  = JSON.parse(@p[3].value.read)

        instancenr = notification['instance']
        content = notification['content']
        attr = content['attributes']
        engine = notification['cpee']

        prefix = File.join(engine,notification['instance-uuid'].to_s)

        if topic == 'state'  && event_name == 'change'
          if %w{abandoned finished}.include?(content['state'])
            parent = redis.get(File.join(prefix,'parent'))
            oldstate = redis.get(File.join(prefix,'state'))
            children = redis.lrange(File.join(prefix,'children'),0,-1)
            redis.multi do |multi|
              multi.decr(File.join(engine,oldstate)) rescue nil
              multi.incr(File.join(engine,'total_' + content['state']))
              multi.lrem(File.join(engine,'instances'),0,notification['instance-uuid'])
              multi.del(File.join(prefix,'instance-url'))
              multi.del(File.join(prefix,'author'))
              multi.del(File.join(prefix,'path'))
              multi.del(File.join(prefix,'name'))
              multi.del(File.join(prefix,'state'))
              multi.del(File.join(prefix,'cpu'))
              multi.del(File.join(prefix,'mem'))
              children.each do |child|
                if parent
                  multi.set(File.join(engine,child,'parent'),parent)
                else
                  multi.del(File.join(engine,child,'parent'))
                end
              end
              multi.del(File.join(prefix,'children'))
              multi.del(File.join(prefix,'parent'))
              if parent
                multi.lrem(File.join(engine,parent,'children'),0,notification['instance-uuid'].to_s)
              end
            end
          elsif %w{ready}.include?(content['state'])
            exi = true if redis.lrange(File.join(engine,'instances'),0,-1).include?(notification['instance-uuid'])
            redis.multi do |multi|
              unless exi
                multi.incr(File.join(engine,'total_created'))
                multi.incr(File.join(engine,'ready'))
                multi.rpush(File.join(engine,'instances'),notification['instance-uuid'])
              end
              multi.set(File.join(prefix,'instance-url'),notification['instance-url'])
              multi.set(File.join(prefix,'author'),attr['author'])
              multi.set(File.join(prefix,'state'),content['state'])
              multi.set(File.join(prefix,'path'),File.join(attr['design_dir'],attr['info']+'.xml')) unless attr['design_dir'].nil? || attr['info'].nil?
              multi.set(File.join(prefix,'name'),attr['info'])
              multi.set(File.join(prefix,'cpu'),0)
              multi.set(File.join(prefix,'mem'),0)
            end
          elsif %w{stopping}.include?(content['state'])
            redis.set(File.join(prefix,'state'),content['state'])
          elsif %w{stopped}.include?(content['state'])
            redis.multi do |multi|
              multi.decr(File.join(engine,'running'))
              multi.incr(File.join(engine,'stopped'))
              multi.set(File.join(prefix,'state'),content['state'])
              multi.set(File.join(prefix,'cpu'),0)
              multi.set(File.join(prefix,'mem'),0)
            end
          elsif %w{running}.include?(content['state'])
            oldstate = redis.get(File.join(prefix,'state'))
            redis.multi do |multi|
              multi.decr(File.join(engine,oldstate)) rescue nil
              multi.incr(File.join(engine,'running'))
              multi.set(File.join(prefix,'state'),content['state'])
            end
          end

          url, author, path, name, state, parent = redis.mget(
            File.join(prefix,'instance-url'),
            File.join(prefix,'author'),
            File.join(prefix,'path'),
            File.join(prefix,'name'),
            File.join(prefix,'state'),
            File.join(prefix,'parent')
          )
          receivers.each do |conn|
            conn.send JSON::generate(:topic => topic, :event => event_name, :engine => engine, :uuid => notification['instance-uuid'], :url => url, :author => author, :path => path.to_s, :name => name, :state => content['state'], :parent => parent.to_s)
          end
        elsif topic == 'task'  && event_name == 'instantiation'
          redis.multi do |multi|
            multi.rpush(File.join(engine,notification['instance-uuid'],'children'),content['received']['CPEE-INSTANCE-UUID'])
            multi.set(File.join(engine,content['received']['CPEE-INSTANCE-UUID'],'parent'),notification['instance-uuid'])
          end
          prefix = File.join(engine,content['received']['CPEE-INSTANCE-UUID'].to_s)
          url, author, path, name, state, parent = redis.mget(
            File.join(prefix,'instance-url'),
            File.join(prefix,'author'),
            File.join(prefix,'path'),
            File.join(prefix,'name'),
            File.join(prefix,'state'),
            File.join(prefix,'parent')
          )
          receivers.each do |conn|
            conn.send JSON::generate(:topic => 'state', :event => 'change', :engine => engine, :uuid => content['received']['CPEE-INSTANCE-UUID'], :url => url, :author => author, :path => path.to_s, :name => name, :state => state, :parent => parent.to_s)
          end
        elsif topic == 'status'  && event_name == 'resource_utilization'
          redis.multi do |multi|
            multi.set(File.join(prefix,'cpu'),content['utime'] + content['stime'])
            multi.set(File.join(prefix,'mem'),content['mib'])
          end
          receivers.each do |conn|
            conn.send JSON::generate(:topic => topic, :event => event_name, :engine => engine, :uuid => notification['instance-uuid'], :cpu => content['utime'] + content['stime'], :mem => content['mib'])
          end
        elsif topic == 'node'  && event_name == 'resource_utilization'
          redis.multi do |multi|
            multi.set(File.join(engine,'cpu_usage'),content['cpu_usage'])
            multi.set(File.join(engine,'mem_free'),content['mem_free'])
            multi.set(File.join(engine,'mem_total'),content['mem_total'])
            multi.set(File.join(engine,'mem_available'),content['mem_available'])
          end
          receivers.each do |conn|
            conn.send JSON::generate(:topic => topic, :event => event_name, :engine => engine, :cpu_usage => content['cpu_usage'], :mem_free => content['mem_free'], :mem_total => content['mem_total'], :mem_available => content['mem_available'])
          end
        end
      end
    end #}}}

    class StatGet < Riddl::Implementation #{{{
      def response
        redis = @a[0]
        engine = @p[0].value
        res = redis.mapped_mget(
          File.join(engine,'total_created'),
          File.join(engine,'total_finished'),
          File.join(engine,'total_abandoned'),
          File.join(engine,'ready'),
          File.join(engine,'stopped'),
          File.join(engine,'running')
        ).transform_keys{ |k| File.basename(k) }.transform_values(&:to_i)
        Riddl::Parameter::Complex.new('stats','application/json',JSON::pretty_generate(res || []))
      end
    end #}}}
    class InstancesGet < Riddl::Implementation #{{{
      def response
        redis = @a[0]
        engine = @p[0].value
        doc = XML::Smart.string('<instances/>')
        redis.lrange(File.join(engine,'instances'),0,-1).each do |i|
          prefix = File.join(engine,i.to_s)
          url, author, path, name, state, cpu, mem, parent = redis.mget(
            File.join(prefix,'instance-url'),
            File.join(prefix,'author'),
            File.join(prefix,'path'),
            File.join(prefix,'name'),
            File.join(prefix,'state'),
            File.join(prefix,'cpu'),
            File.join(prefix,'mem'),
            File.join(prefix,'parent')
          )
          doc.root.add('instance', :uuid => i, :url => url, :author => author, :path => path, :name => name, :state => state, :cpu => cpu, :mem => mem, :parent => parent)
        end
        Riddl::Parameter::Complex.new('tree','text/xml',doc.to_s)
      end
    end #}}}
    class InstanceGet < Riddl::Implementation #{{{
      def response
        redis = @a[0]
        engine = @p[0].value
        uuid = @r[-1]
        prefix = File.join(engine,uuid.to_s)
        url, author, path, name, state, cpu, mem, parent = redis.mget(
          File.join(prefix,'instance-url'),
          File.join(prefix,'author'),
          File.join(prefix,'path'),
          File.join(prefix,'name'),
          File.join(prefix,'state'),
          File.join(prefix,'cpu'),
          File.join(prefix,'mem'),
          File.join(prefix,'parent')
        )
        Riddl::Parameter::Complex.new('instance','application/json',JSON.generate(:uuid => uuid, :url => url, :author => author, :path => path, :name => name, :state => state, :cpu => cpu, :mem => mem, :parent => parent))
      end
    end #}}}


    def self::implementation(opts)
      opts[:management_receivers] = []
      opts[:stat_receivers] = []

      ### set redis_cmd to nil if you want to do global
      ### at least redis_path or redis_url and redis_db have to be set if you do global
      opts[:redis_path]                 ||= 'redis.sock' # use e.g. /tmp/redis.sock for global stuff. Look it up in your redis config
      opts[:redis_db]                   ||= 0
      ### optional redis stuff
      opts[:redis_url]                  ||= nil
      opts[:redis_cmd]                  ||= 'redis-server --port 0 --unixsocket #redis_path# --unixsocketperm 600 --pidfile #redis_pid# --dir #redis_db_dir# --dbfilename #redis_db_name# --databases 1 --save 900 1 --save 300 10 --save 60 10000 --rdbcompression yes --daemonize yes'
      opts[:redis_pid]                  ||= 'redis.pid' # use e.g. /var/run/redis.pid if you do global. Look it up in your redis config
      opts[:redis_db_name]              ||= 'redis.rdb' # use e.g. /var/lib/redis.rdb for global stuff. Look it up in your redis config

      CPEE::redis_connect opts, 'Server Main'

      Proc.new do
        interface 'events' do
          run StatReceive, opts[:redis], opts[:stat_receivers] if post 'event'
        end
        interface 'implementation' do
          run GetList, :main, opts[:views], opts[:models] if get 'stage'
          run GetListFull, opts[:views], opts[:models] if get 'full'
          run GetStages, opts[:themes] if get 'stages'
          run Create, :main, :cre, opts[:views], opts[:management_receivers], opts[:templates], opts[:models] if post 'item'
          run Create, :main, :dup, opts[:views], opts[:management_receivers], opts[:templates], opts[:models] if post 'duplicate'
          run CreateDir, opts[:management_receivers], opts[:models] if post 'dir'
          run ManagementSend, opts[:management_receivers] if sse
          on resource '[a-zA-Z0-9öäüÖÄÜ _-]+\.dir' do
            run GetList, :sub, opts[:views], opts[:models] if get 'stage'
            run Create, :sub, :cre, opts[:views], opts[:management_receivers], opts[:templates], opts[:models] if post 'item'
            run Create, :sub, :dup, opts[:views], opts[:management_receivers], opts[:templates], opts[:models] if post 'duplicate'
            run DeleteDir, opts[:management_receivers], opts[:models] if delete
            run RenameDir, opts[:management_receivers], opts[:models] if put 'name'
            on resource '[a-zA-Z0-9öäüÖÄÜ _-]+\.xml' do
              run DeleteItem, :sub, opts[:management_receivers], opts[:models] if delete
              run GetItem, :sub, opts[:models] if get
              run PutItem, :sub, opts[:management_receivers], opts[:models] if put 'content'
              run RenameItem, :sub, opts[:management_receivers], opts[:models] if put 'name'
              run MoveItem, :sub, opts[:management_receivers], opts[:models] if put 'dirname'
              run ShiftItem, :sub, opts[:management_receivers], opts[:themes], opts[:models] if put 'newstage'
              on resource 'open' do
                run OpenItem, :sub, opts[:instantiate], opts[:cockpit], opts[:views], false, opts[:models] if get 'stage'
              end
              on resource 'open-new' do
                run OpenItem, :sub, opts[:instantiate], opts[:cockpit], opts[:views], true, opts[:models] if get 'stage'
              end
            end
          end
          on resource '[a-zA-Z0-9öäüÖÄÜ _-]+\.xml' do
            run DeleteItem, :main, opts[:management_receivers], opts[:models] if delete
            run GetItem, :main, opts[:models] if get
            run PutItem, :main, opts[:management_receivers], opts[:models] if put 'content'
            run RenameItem, :main, opts[:management_receivers], opts[:models] if put 'name'
            run MoveItem, :main, opts[:management_receivers], opts[:models] if put 'dirname'
            run ShiftItem, :main, opts[:management_receivers], opts[:themes], opts[:models] if put 'newstage'
            on resource 'open' do
              run OpenItem, :main, opts[:instantiate], opts[:cockpit], opts[:views], false, opts[:models] if get 'stage'
            end
            on resource 'open-new' do
              run OpenItem, :main, opts[:instantiate], opts[:cockpit], opts[:views], true, opts[:models] if get 'stage'
            end
          end
          on resource 'dash' do
            on resource 'show' do
              run ShowUrl, opts[:show] if get 'url'
            end
            on resource 'abandon' do
              run AbandonUrl if put 'url'
            end
            on resource 'events' do
              run StatSend, opts[:stat_receivers] if sse
            end
            on resource 'instances' do
              run InstancesGet, opts[:redis] if get 'engine'
              on resource do
                run InstanceGet, opts[:redis] if get 'engine'
              end
            end
            on resource 'stats' do
              run StatGet, opts[:redis] if get 'engine'
            end
          end
        end
      end
    end

  end
end
