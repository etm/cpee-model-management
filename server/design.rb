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

class GetList < Riddl::Implementation
  def response
    names = Dir.glob(File.join(__dir__,'models','*.xml')).map do |f|
      File.basename(f)
    end
    Riddl::Parameter::Complex.new('list','application/json',JSON::pretty_generate(names))
  end
end

class GetItem < Riddl::Implementation
  def response
    name  = @r.last
    insta = @a[0]
    cock  = @a[1]
    status, result, headers = Riddl::Client.new(File.join(insta,'xml')).post [
      Riddl::Parameter::Simple.new('behavior','fork_ready'),
      Riddl::Parameter::Complex.new('xml','application/xml',File.read('testset.xml'))
    ]
    if status >= 200 && status < 300
      inst = JSON::parse(result[0].value.read)
      insturl = inst['CPEE-INSTANCE-URL']
      @status = 302
      @headers << Riddl::Header.new('Location',cock + insturl)
    else
      @status = 400
    end

    nil
  end

end

class PutItem < Riddl::Implementation
  def response
    p @r
  end
end

server = Riddl::Server.new(File.join(__dir__,'/design.xml'), :host => 'localhost', :port => 9316) do |opts|
  accessible_description true
  cross_site_xhr true

  on resource do
    run GetList if get
    on resource '[a-zA-Z0-9öäüÖÄÜ _-]+\.xml' do
      run GetItem, @riddl_opts[:instantiate], @riddl_opts[:cockpit] if get
      run PutItem if put 'content'
    end
  end
end.loop!
