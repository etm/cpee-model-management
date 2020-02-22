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
require 'fileutils'

class GetList < Riddl::Implementation
  def response
    names = Dir.glob(File.join(__dir__,'models','*.xml')).map do |f|
      { :name => File.basename(f), :creator => File.read(f + '.creator'), :author => File.read(f + '.author'), :date => File.mtime(f).xmlschema }
    end
    Riddl::Parameter::Complex.new('list','application/json',JSON::pretty_generate(names))
  end
end

class Create < Riddl::Implementation
  def response
    name = @p[0].value
    fname = File.join('models',name + '.xml')
    counter = 0
    while File.exists?(fname)
      counter += 1
      fname = File.join('models',name + counter.to_s + '.xml')
    end

    dn = @h['DN'].split(',').map{ |e| e.split('=',2) }.to_h
    FileUtils.cp('testset.xml',fname)
    XML::Smart::modify(fname) do |doc|
      doc.register_namespace 'p', 'http://riddl.org/ns/common-patterns/properties/1.0'
      doc.find('/testset/attributes/p:info').each do |ele|
        ele.text = File.basename(fname,'.xml')
      end
      doc.find('/testset/attributes/p:creator').each do |ele|
        ele.text = dn['GN'] + ' ' + dn['SN']
      end
      doc.find('/testset/attributes/p:author').each do |ele|
        ele.text = dn['GN'] + ' ' + dn['SN']
      end
    end
    File.write(fname + '.creator',dn['GN'] + ' ' + dn['SN'])
    File.write(fname + '.author',dn['GN'] + ' ' + dn['SN'])
    nil
  end
end

class GetItem < Riddl::Implementation
  def response
    name   = File.basename(@r.last,'.xml')
    insta  = @a[0]
    cock   = @a[1]
    active = @a[2]
    inst   = if active[name]
      { 'CPEE-INSTANCE-URL' => File.read(File.join('models',name + '.xml.active')) } rescue nil
    else
      status, result, headers = Riddl::Client.new(File.join(insta,'xml')).post [
        Riddl::Parameter::Simple.new('behavior','fork_ready'),
        Riddl::Parameter::Complex.new('xml','application/xml',File.read(File.join('models',name + '.xml')))
      ]
      if status >= 200 && status < 300
        JSON::parse(result[0].value.read)
      else
        nil
      end
    end
    if inst.nil?
      @status = 400
    else
      insturl = inst['CPEE-INSTANCE-URL']
      @status = 302
      @headers << Riddl::Header.new('Location',cock + insturl)
    end
    nil
  end

end

class PutItem < Riddl::Implementation
  def response
    name  = File.basename(@r.last,'.xml')
    cont = @p[0].value.read
    dn = @h['DN'].split(',').map{ |e| e.split('=',2) }.to_h
    XML::Smart.string(cont) do |doc|
      doc.register_namespace 'p', 'http://riddl.org/ns/common-patterns/properties/1.0'
      unless File.exists?(File.join('models',name + '.xml.creator'))
        doc.find('/testset/attributes/p:author').each do |ele|
          File.write(File.join('models',name + '.xml.creator'),ele.text)
        end
      end
      doc.find('/testset/attributes/p:author').each do |ele|
        ele.text = dn['GN'] + ' ' + dn['SN']
      end
      File.write(File.join('models',name + '.xml'),doc.to_s)
      File.write(File.join('models',name + '.xml.author'),dn['GN'] + ' ' + dn['SN'])
    end
  end
end

class DeleteItem < Riddl::Implementation
  def response
    name  = File.basename(@r.last,'.xml')
    File.delete(File.join('models',name + '.xml'))
    File.delete(File.join('models',name + '.xml.author'))
    File.delete(File.join('models',name + '.xml.creator'))
  end
end

class Active < Riddl::SSEImplementation
  def onopen
    @active = @a[0]
    @name = @r.last
    @active[@name] = File.read(File.join('models',@name + '.xml.active')) rescue nil
  end
  def onclose
    @active.delete(@r[0])
  end
end

server = Riddl::Server.new(File.join(__dir__,'/design.xml'), :host => 'localhost', :port => 9316) do |opts|
  accessible_description true
  cross_site_xhr true

  @riddl_opts[:active] = {}

  on resource do
    run GetList if get
    run Create if post 'name'
    on resource '[a-zA-Z0-9öäüÖÄÜ _-]+\.xml' do
      run DeleteItem if delete
      run GetItem, @riddl_opts[:instantiate], @riddl_opts[:cockpit], @riddl_opts[:active] if get
      run PutItem if put 'content'
      run Active, @riddl_opts[:active] if sse
    end
  end
end.loop!
