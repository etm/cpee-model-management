#!/usr/bin/ruby
#
# This file is part of centurio.work/ing/commands.
#
# centurio.work/ing/commands is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# centurio.work/ing/commands is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# centurio.work/ing/commands (file COPYING in the main directory). If not, see
# <http://www.gnu.org/licenses/>.

require 'rubygems'
require 'json'
require 'riddl/server'
require 'riddl/client'
require 'riddl/protocols/utils'
require 'fileutils'

class GetList < Riddl::Implementation
  def response
    where = @a[0] == :main ? '' : Riddl::Protocols::Utils::unescape(@r.last)
    views = @a[1]
    stage = @p[0]&.value || 'draft'
    stage = views[stage] if views && views[stage]

    names = Dir.glob(File.join('models',where,'*.dir')).map do |f|
      { :type => :dir, :name => File.basename(f), :creator => File.read(f + '.creator'), :date => File.mtime(f).xmlschema }
    end.compact.uniq.sort_by{ |e| e[:name] } + Dir.glob(File.join('models',where,'*.xml')).map do |f|
      fstage = File.read(f + '.stage').strip rescue 'draft'
      { :type => :file, :name => File.basename(f), :creator => File.read(f + '.creator'), :author => File.read(f + '.author'), :stage => fstage, :date => File.mtime(f).xmlschema } if fstage == stage
    end.compact.uniq.sort_by{ |e| e[:name] }

    Riddl::Parameter::Complex.new('list','application/json',JSON::pretty_generate(names))
  end
end
class GetListFull < Riddl::Implementation
  def response
    views = @a[0]
    stage = @p[0]&.value || 'draft'
    stage = views[stage] if views && views[stage]

    names = Dir.glob(File.join('models','*.dir/*.xml')).map do |f|
      { :type => :file, :name => File.join(File.basename(File.dirname(f)),File.basename(f)), :creator => File.read(f + '.creator'), :date => File.mtime(f).xmlschema }
    end.compact.uniq.sort_by{ |e| e[:name] } + Dir.glob(File.join('models','*.xml')).map do |f|
      fstage = File.read(f + '.stage').strip rescue 'draft'
      { :type => :file, :name => File.basename(f), :creator => File.read(f + '.creator'), :author => File.read(f + '.author'), :stage => fstage, :date => File.mtime(f).xmlschema } if fstage == stage
    end.compact.uniq.sort_by{ |e| e[:name] }

    Riddl::Parameter::Complex.new('list','application/json',JSON::pretty_generate(names))
  end
end

class RenameItem < Riddl::Implementation
  def response
    where = @a[0] == :main ? '' : Riddl::Protocols::Utils::unescape(@r[-2])
    name  = File.basename(@r.last,'.xml')
    nname = @p[0].value
    fnname = File.join('models',where,nname + '.xml')
    counter = 0
    stage = 'draft'
    while File.exists?(fnname)
      counter += 1
      fnname = File.join('models',where,nname + counter.to_s + '.xml')
    end

    dn = @h['DN'].split(',').map{ |e| e.split('=',2) }.to_h
    creator = dn['GN'] + ' ' + dn['SN']

    FileUtils.cp(File.join('models',where,name + '.xml'),fnname)
    XML::Smart::modify(fnname) do |doc|
      doc.register_namespace 'p', 'http://cpee.org/ns/properties/2.0'
      creator = doc.find('string(/p:testset/p:attributes/p:creator)')
      doc.find('/p:testset/p:attributes/p:info').each do |ele|
        ele.text = File.basename(fnname,'.xml')
      end
      doc.find('/p:testset/p:attributes/p:author').each do |ele|
        ele.text = dn['GN'] + ' ' + dn['SN']
      end
      stage = doc.find('string(/p:testset/p:attributes/p:design_stage)').sub(/^$/,'draft')
    end
    File.write(fnname + '.creator',creator)
    File.write(fnname + '.author',dn['GN'] + ' ' + dn['SN'])
    File.write(fnname + '.stage',stage)
    nil
  end
end

class CreateDir < Riddl::Implementation
  def response
    name = @p[0].value

    fname = File.join('models',name + '.dir')
    counter = 0
    while File.exists?(fname)
      counter += 1
      fname = File.join('models',name + counter.to_s + '.dir')
    end

    dn = @h['DN'].split(',').map{ |e| e.split('=',2) }.to_h

    Dir.mkdir(fname)
    File.write(fname + '.creator',dn['GN'] + ' ' + dn['SN'])
    nil
  end
end

class Create < Riddl::Implementation
  def response
    where = @a[0] == :main ? '' : Riddl::Protocols::Utils::unescape(@r.last)
    stage = if @a[1] == :cre
      @p.shift.value
    else
      nil
    end
    views = @a[2]
    stage = views[stage] if views && views[stage]

    name = @p[0].value
    tname = @p[1] ? File.join('models',where,@p[1].value) : 'testset.xml'

    fname = File.join('models',where,name + '.xml')
    counter = 0
    while File.exists?(fname)
      counter += 1
      fname = File.join('models',where,name + counter.to_s + '.xml')
    end

    dn = @h['DN'].split(',').map{ |e| e.split('=',2) }.to_h
    FileUtils.cp(tname,fname)
    XML::Smart::modify(fname) do |doc|
      doc.register_namespace 'p', 'http://cpee.org/ns/properties/2.0'
      doc.find('/p:testset/p:attributes/p:info').each do |ele|
        ele.text = File.basename(fname,'.xml')
      end
      doc.find('/p:testset/p:attributes/p:creator').each do |ele|
        ele.text = dn['GN'] + ' ' + dn['SN']
      end
      doc.find('/p:testset/p:attributes/p:author').each do |ele|
        ele.text = dn['GN'] + ' ' + dn['SN']
      end
      doc.find('/p:testset/p:attributes/p:design_dir').each do |ele|
        ele.text = where
      end
      if stage
        doc.find('/p:testset/p:attributes/p:design_stage').each do |ele|
          ele.text = stage
        end
      end
    end
    File.write(fname + '.creator',dn['GN'] + ' ' + dn['SN'])
    File.write(fname + '.author',dn['GN'] + ' ' + dn['SN'])
    File.write(fname + '.stage',stage)
    nil
  end
end

class GetItem < Riddl::Implementation
  def response
    where = @a[0] == :main ? '' : Riddl::Protocols::Utils::unescape(@r[-2])
    name   = File.basename(@r[-1],'.xml')
    fname = File.join('models',where,name + '.xml')
    if File.exists? fname
      Riddl::Parameter::Complex.new('content','application/xml',File.read(fname))
    else
      @status = 400
    end
  end
end

class OpenItem < Riddl::Implementation
  def response
    where = @a[0] == :main ? '' : Riddl::Protocols::Utils::unescape(@r[-3])
    name   = File.basename(@r[-2],'.xml')
    insta  = @a[1]
    cock   = @a[2]
    active = @a[3]
    views  = @a[4]
    stage  = @p[0]&.value || 'draft'

    inst   = if active[name]
      { 'CPEE-INSTANCE-URL' => File.read(File.join('models',where,name + '.xml.active')) } rescue nil
    else
      status, result, headers = Riddl::Client.new(File.join(insta,'xml')).post [
        Riddl::Parameter::Simple.new('behavior','fork_ready'),
        Riddl::Parameter::Complex.new('xml','application/xml',File.read(File.join('models',where,name + '.xml')))
      ] rescue nil
      if status && status >= 200 && status < 300
        JSON::parse(result[0].value.read)
      else
        nil
      end
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
end

class MoveItem < Riddl::Implementation
  def response
    where = @a[0] == :main ? '' : Riddl::Protocols::Utils::unescape(@r[-2])
    name  = File.basename(@r.last,'.xml')
    to = @p[0].value
    fname = File.join('models',where,name + '.xml')

    if !File.exist?(File.join('models',to,name + '.xml'))
      XML::Smart::modify(fname) do |doc|
        doc.register_namespace 'p', 'http://cpee.org/ns/properties/2.0'
        doc.find('/p:testset/p:attributes/p:design_dir').each do |ele|
          ele.text = to
        end
      end
      FileUtils.mv(Dir.glob(fname + '*'),File.join('models',to))
    end
  end
end

class PutItem < Riddl::Implementation
  def response
    where = @a[0] == :main ? '' : Riddl::Protocols::Utils::unescape(@r[-2])
    name  = File.basename(@r.last,'.xml')
    cont = @p[0].value.read
    dn = @h['DN'].split(',').map{ |e| e.split('=',2) }.to_h
    XML::Smart.string(cont) do |doc|
      doc.register_namespace 'p', 'http://cpee.org/ns/properties/2.0'
      unless File.exists?(File.join('models',where,name + '.xml.creator'))
        doc.find('/p:testset/p:attributes/p:author').each do |ele|
          File.write(File.join('models',where,name + '.xml.creator'),ele.text)
        end
      end
      doc.find('/p:testset/p:attributes/p:author').each do |ele|
        ele.text = dn['GN'] + ' ' + dn['SN']
      end
      File.write(File.join('models',where,name + '.xml'),doc.to_s)
      File.write(File.join('models',where,name + '.xml.author'),dn['GN'] + ' ' + dn['SN'])
      File.write(File.join('models',where,name + '.xml.stage'),doc.find('string(/p:testset/p:attributes/p:design_stage)').sub(/^$/,'draft'))
    end
  end
end

class DeleteItem < Riddl::Implementation
  def response
    where = @a[0] == :main ? '' : Riddl::Protocols::Utils::unescape(@r[-2])
    name  = File.basename(@r.last,'.xml')
    File.delete(File.join('models',where,name + '.xml'))
    File.delete(File.join('models',where,name + '.xml.author'))
    File.delete(File.join('models',where,name + '.xml.creator'))
    File.delete(File.join('models',where,name + '.xml.stage'))
  end
end

class Active < Riddl::SSEImplementation
  def onopen
    @where = @a[0] == :main ? '' : Riddl::Protocols::Utils::unescape(@r[-2])
    @active = @a[1]
    @name = @r.last
    @active[@name] = File.read(File.join('models',@name + '.xml.active')) rescue nil
  end
  def onclose
    @active.delete(@r[0])
  end
end

server = Riddl::Server.new(File.join(__dir__,'/design.xml'), :host => 'localhost') do |opts|
  accessible_description true
  cross_site_xhr true

  @riddl_opts[:active] = {}

  on resource do
    run GetList, :main, @riddl_opts[:views] if get 'stage'
    run GetListFull, @riddl_opts[:views] if get 'full'
    run Create, :main, :cre, @riddl_opts[:views] if post 'item'
    run Create, :main, :dup, @riddl_opts[:views] if post 'duplicate'
    run CreateDir if post 'dir'
    on resource '[a-zA-Z0-9öäüÖÄÜ _-]+\.dir' do
      run GetList, :sub, @riddl_opts[:views] if get 'stage'
      run Create, :sub, :cre, @riddl_opts[:views] if post 'item'
      run Create, :sub, :dup, @riddl_opts[:views] if post 'duplicate'
      on resource '[a-zA-Z0-9öäüÖÄÜ _-]+\.xml' do
        run DeleteItem, :sub if delete
        run GetItem, :sub if get
        run PutItem, :sub if put 'content'
        run RenameItem, :sub if put 'name'
        run MoveItem, :sub if put 'move'
        run Active, :sub, @riddl_opts[:active] if sse
        on resource 'open' do
          run OpenItem, :sub, @riddl_opts[:instantiate], @riddl_opts[:cockpit], @riddl_opts[:active], @riddl_opts[:views] if get
        end
      end
    end
    on resource '[a-zA-Z0-9öäüÖÄÜ _-]+\.xml' do
      run DeleteItem, :main if delete
      run GetItem, :main if get
      run PutItem, :main if put 'content'
      run RenameItem, :main if put 'name'
      run MoveItem, :main if put 'move'
      run Active, :main, @riddl_opts[:active] if sse
      on resource 'open' do
        run OpenItem, :main, @riddl_opts[:instantiate], @riddl_opts[:cockpit], @riddl_opts[:active], @riddl_opts[:views] if get 'stage'
      end
    end
  end
end.loop!
