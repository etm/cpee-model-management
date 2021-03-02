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

def op(author,op,new,old=nil) #{{{
  if File.exists?(File.join('models','.git'))
    cdir = Dir.pwd
    Dir.chdir('models')
    case op
      when 'mv'
        fname  = old
        fnname = new
        `git mv "#{fname}"                  "#{fnname}" 2>/dev/null`
        `git rm -rf "#{fname + '.active'}"      "#{fnname + '.active'}" 2>/dev/null`
        `git rm -rf "#{fname + '.active-uuid'}" "#{fnname + '.active-uuid'}" 2>/dev/null`
        `git mv "#{fname + '.author'}"      "#{fnname + '.author'}" 2>/dev/null`
        `git mv "#{fname + '.creator'}"     "#{fnname + '.creator'}" 2>/dev/null`
        `git mv "#{fname + '.stage'}"       "#{fnname + '.stage'}" 2>/dev/null`
      when 'rm'
        fname = new
        `git rm -rf "#{fname}" 2>/dev/null`
         FileUtils.rm_rf(fname)
        `git rm -rf "#{fname}.active" 2>/dev/null`
        `git rm -rf "#{fname}.active-uuid" 2>/dev/null`
        `git rm -rf "#{fname}.author" 2>/dev/null`
        `git rm -rf "#{fname}.creator" 2>/dev/null`
        `git rm -rf "#{fname}.stage" 2>/dev/null`
      when 'shift'
        fname = new
        `git rm -rf "#{fname}.active" 2>/dev/null`
        `git rm -rf "#{fname}.active-uuid" 2>/dev/null`
    end
    fname = new
    `git add "#{fname}" 2>/dev/null`
    `git add "#{fname}.active" 2>/dev/null`
    `git add "#{fname}.active-uuid" 2>/dev/null`
    `git add "#{fname}.author" 2>/dev/null`
    `git add "#{fname}.creator" 2>/dev/null`
    `git add "#{fname}.stage" 2>/dev/null`
    `git commit -m "#{author.gsub(/"/,"'")}"`
    Dir.chdir(cdir)
  else
    case op
      when 'mv'
        fname = File.join('models',old)
        fnname = File.join('models',new)
        FileUtils.mv(fname,fnname)
        File.delete(fname + '.active',fnname + '.active') rescue nil
        File.delete(fname + '.active-uuid',fnname + '.active-uuid') rescue nil
        FileUtils.mv(fname + '.author',fnname + '.author') rescue nil
        FileUtils.mv(fname + '.creator',fnname + '.creator') rescue nil
        FileUtils.mv(fname + '.stage',fnname + '.stage') rescue nil
      when 'rm'
        fname = File.join('models',new)
        FileUtils.rm_rf(fname)
        File.delete(fname + '.active') rescue nil
        File.delete(fname + '.active-uuid') rescue nil
        File.delete(fname + '.author') rescue nil
        File.delete(fname + '.creator') rescue nil
        File.delete(fname + '.stage') rescue nil
      when 'shift'
        fname = File.join('models',new)
        File.delete(fname + '.active') rescue nil
        File.delete(fname + '.active-uuid') rescue nil
    end
  end
end #}}}
def get_dn(dn) #{{{
  if dn
    dn.split(',').map{ |e| e.split('=',2) }.to_h
  else
    { 'GN' => 'Christine', 'SN' => 'Ashcreek' }
  end
end #}}}
def notify(conns,op,f,s=nil) #{{{
  what = if f =~ /\.dir$/
    if  op == 'delete'
      { :op => op, :type => :dir, :name => File.basename(f) }
    else
      { :op => op, :type => :dir, :name => File.basename(f), :creator => File.read(f + '.creator'), :date => File.mtime(f).xmlschema }
    end
  else
    if  op == 'delete'
      { :op => op, :type => :file, :name => f.sub(/models\//,'') }
    else
      fstage = File.read(f + '.stage').strip rescue 'draft'
      { :op => op, :type => :file, :name => f.sub(/models\//,''), :creator => File.read(f + '.creator'), :author => File.read(f + '.author'), :stage => fstage, :date => File.mtime(f).xmlschema }
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
end #}}}
class GetListFull < Riddl::Implementation #{{{
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
    name  = File.basename(@r.last,'.xml')
    nstage = @p[0].value
    fname  = File.join('models',where,name + '.xml')

    dn = get_dn @h['DN']
    author = dn['GN'] + ' ' + dn['SN']

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
    end
    File.write(fname + '.author',author)
    File.write(fname + '.stage',nstage)

    op author, 'shift', File.join('.', where, name + '.xml'), File.join('.', where, name + '.xml')
    notify conns, 'shift', fname, fname
    nil
  end
end #}}}

class RenameItem < Riddl::Implementation #{{{
  def response
    where = @a[0] == :main ? '' : Riddl::Protocols::Utils::unescape(@r[-2])
    conns = @a[1]
    name  = File.basename(@r.last,'.xml')
    nname = @p[0].value
    fname  = File.join('models',where,name + '.xml')
    fnname = File.join('models',where,nname + '.xml')
    counter = 0
    stage = 'draft'
    while File.exists?(fnname)
      counter += 1
      fnname = File.join('models',where,nname + counter.to_s + '.xml')
    end

    dn = get_dn @h['DN']
    author = dn['GN'] + ' ' + dn['SN']

    XML::Smart::modify(fname) do |doc|
      doc.register_namespace 'p', 'http://cpee.org/ns/properties/2.0'
      doc.find('/p:testset/p:attributes/p:info').each do |ele|
        ele.text = File.basename(fnname,'.xml')
      end
      doc.find('/p:testset/p:attributes/p:author').each do |ele|
        ele.text = author
      end
    end
    File.write(fname + '.author',author)

    op author, 'mv', File.join('.', where, nname + '.xml'), File.join('.', where, name + '.xml')
    notify conns, 'rename', fnname, fname
    nil
  end
end #}}}
class RenameDir < Riddl::Implementation #{{{
  def response
    conns = @a[0]
    name  = File.basename(@r.last,'.dir')
    nname = @p[0].value
    fname  = File.join('models',name + '.dir')
    fnname = File.join('models',nname + '.dir')
    counter = 0
    while File.exists?(fnname)
      counter += 1
      fnname = File.join('models',nname + counter.to_s + '.dir')
    end

    dn = get_dn @h['DN']
    author = dn['GN'] + ' ' + dn['SN']
    File.write(fname + '.author',author)

    op author, 'mv', File.join(nname + '.dir'), File.join(name + '.dir')
    notify conns, 'rename', fnname, fname
    nil
  end
end #}}}

class CreateDir < Riddl::Implementation #{{{
  def response
    name = @p[0].value
    conns = @a[0]

    fname = File.join('models',name + '.dir')
    counter = 0
    while File.exists?(fname)
      counter += 1
      fname = File.join('models',name + counter.to_s + '.dir')
    end

    dn = get_dn @h['DN']
    creator = dn['GN'] + ' ' + dn['SN']

    Dir.mkdir(fname)
    FileUtils.touch(File.join(fname,'.gitignore'))
    File.write(fname + '.creator',creator)
    File.write(fname + '.author',creator)

    op creator, 'add', name + '.dir'
    notify conns, 'create', fname
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

    name = @p[0].value
    source = @p[1] ? File.join('models',where,@p[1].value) : (templates[stage] ? templates[stage] : 'testset.xml')
    fname = File.join('models',where,name + '.xml')

    stage = File.read(source + '.stage') if stage.nil? && File.exists?(source + '.stage')
    stage = views[stage] if views && views[stage]

    counter = 0
    while File.exists?(fname)
      counter += 1
      fname = File.join('models',where,name + counter.to_s + '.xml')
    end

    dn = get_dn @h['DN']
    creator = dn['GN'] + ' ' + dn['SN']
    FileUtils.cp(source,fname)
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
      if stage
        doc.find('/p:testset/p:attributes/p:design_stage').each do |ele|
          ele.text = stage
        end
      end
    end
    File.write(fname + '.creator',creator)
    File.write(fname + '.author',creator)
    File.write(fname + '.stage',stage)

    op creator, 'add', File.join('.', where, name + '.xml')
    notify conns, 'create', fname
    nil
  end
end #}}}

class GetItem < Riddl::Implementation #{{{
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
end #}}}
class OpenItem < Riddl::Implementation #{{{
  def response
    where = @a[0] == :main ? '' : Riddl::Protocols::Utils::unescape(@r[-3])
    name   = File.basename(@r[-2],'.xml')
    insta  = @a[1]
    cock   = @a[2]
    views  = @a[3]
    force  = @a[4]
    stage  = @p[0]&.value || 'draft'

    fname  = File.join('models',where,name + '.xml')

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
class MoveItem < Riddl::Implementation #{{{
  def response
    where = @a[0] == :main ? '' : Riddl::Protocols::Utils::unescape(@r[-2])
    conns = @a[1]

    name  = File.basename(@r.last,'.xml')
    to = @p[0].value

    fname = File.join('models',where,name + '.xml')
    dn = get_dn @h['DN']
    author = dn['GN'] + ' ' + dn['SN']
    if !File.exist?(File.join('models',to,name + '.xml'))
      XML::Smart::modify(fname) do |doc|
        doc.register_namespace 'p', 'http://cpee.org/ns/properties/2.0'
        doc.find('/p:testset/p:attributes/p:design_dir').each do |ele|
          ele.text = to
        end
      end
      File.write(fname + '.author',author)

      op author, 'mv', File.join('.', to, name + '.xml'), File.join('.', where, name + '.xml')
      notify conns, 'move', File.join('models',to,name + '.xml'), fname
    end
  end
end #}}}
class PutItem < Riddl::Implementation #{{{
  def response
    where = @a[0] == :main ? '' : Riddl::Protocols::Utils::unescape(@r[-2])
    conns = @a[1]
    name  = File.basename(@r.last,'.xml')
    cont = @p[0].value.read
    dn = get_dn @h['DN']

    fname = File.join('models',where,name + '.xml')

    if File.exists?(fname)
      author = dn['GN'] + ' ' + dn['SN']
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
        File.write(fname,doc.to_s)
        File.write(fname + '.author',author)
        File.write(fname + '.stage',doc.find('string(/p:testset/p:attributes/p:design_stage)').sub(/^$/,'draft'))
      end
      op author, 'add', File.join('.', where, name + '.xml')
      notify conns, 'put', fname
    else
      @status = 400
    end
  end
end #}}}
class DeleteItem < Riddl::Implementation #{{{
  def response
    where = @a[0] == :main ? '' : Riddl::Protocols::Utils::unescape(@r[-2])
    conns = @a[1]
    name  = File.basename(@r.last,'.xml')
    fname = File.join('models',where,name + '.xml')

    dn     = get_dn @h['DN']
    author = dn['GN'] + ' ' + dn['SN']

    op author, 'rm', File.join('.', where, name + '.xml')
    notify conns, 'delete', fname
  end
end #}}}
class DeleteDir < Riddl::Implementation #{{{
  def response
    conns = @a[0]
    name  = File.basename(@r.last,'.dir')
    fname = File.join('models',name + '.dir')

    dn     = get_dn @h['DN']
    author = dn['GN'] + ' ' + dn['SN']

    op author, 'rm', File.join(name + '.dir')
    notify conns, 'delete', fname
  end
end #}}}

class Active < Riddl::SSEImplementation #{{{
  def onopen
    @conns = @a[0]
    @conns << self
  end
  def onclose
    @conns.delete(self)
  end
end #}}}

server = Riddl::Server.new(File.join(__dir__,'/design.xml'), :host => 'localhost') do |opts| #{{{
  accessible_description true
  cross_site_xhr true

  @riddl_opts[:connections] = []

  on resource do
    run GetList, :main, @riddl_opts[:views] if get 'stage'
    run GetListFull, @riddl_opts[:views] if get 'full'
    run GetStages, @riddl_opts[:themes] if get 'stages'
    run Create, :main, :cre, @riddl_opts[:views], @riddl_opts[:connections], @riddl_opts[:templates] if post 'item'
    run Create, :main, :dup, @riddl_opts[:views], @riddl_opts[:connections], @riddl_opts[:templates] if post 'duplicate'
    run CreateDir, @riddl_opts[:connections] if post 'dir'
    run Active, @riddl_opts[:connections] if sse
    on resource '[a-zA-Z0-9öäüÖÄÜ _-]+\.dir' do
      run GetList, :sub, @riddl_opts[:views] if get 'stage'
      run Create, :sub, :cre, @riddl_opts[:views], @riddl_opts[:connections], @riddl_opts[:templates] if post 'item'
      run Create, :sub, :dup, @riddl_opts[:views], @riddl_opts[:connections], @riddl_opts[:templates] if post 'duplicate'
      run DeleteDir, @riddl_opts[:connections] if delete
      run RenameDir, @riddl_opts[:connections] if put 'name'
      on resource '[a-zA-Z0-9öäüÖÄÜ _-]+\.xml' do
        run DeleteItem, :sub, @riddl_opts[:connections] if delete
        run GetItem, :sub if get
        run PutItem, :sub, @riddl_opts[:connections] if put 'content'
        run RenameItem, :sub, @riddl_opts[:connections] if put 'name'
        run MoveItem, :sub, @riddl_opts[:connections] if put 'dirname'
        run ShiftItem, :sub, @riddl_opts[:connections], @riddl_opts[:themes] if put 'newstage'
        on resource 'open' do
          run OpenItem, :sub, @riddl_opts[:instantiate], @riddl_opts[:cockpit], @riddl_opts[:views], false if get 'stage'
        end
        on resource 'open-new' do
          run OpenItem, :sub, @riddl_opts[:instantiate], @riddl_opts[:cockpit], @riddl_opts[:views], true if get 'stage'
        end
      end
    end
    on resource '[a-zA-Z0-9öäüÖÄÜ _-]+\.xml' do
      run DeleteItem, :main, @riddl_opts[:connections] if delete
      run GetItem, :main if get
      run PutItem, :main, @riddl_opts[:connections] if put 'content'
      run RenameItem, :main, @riddl_opts[:connections] if put 'name'
      run MoveItem, :main, @riddl_opts[:connections] if put 'dirname'
      run ShiftItem, :main, @riddl_opts[:connections], @riddl_opts[:themes] if put 'newstage'
      on resource 'open' do
        run OpenItem, :main, @riddl_opts[:instantiate], @riddl_opts[:cockpit], @riddl_opts[:views], false if get 'stage'
      end
      on resource 'open-new' do
        run OpenItem, :main, @riddl_opts[:instantiate], @riddl_opts[:cockpit], @riddl_opts[:views], true if get 'stage'
      end
    end
  end
end.loop! #}}}
