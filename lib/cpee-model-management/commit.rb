models = ARGV[0]
new = ARGV[1]
author = ARGV[2]

Dir.chdir(File.join(models,File.dirname(new)))
new = File.basename(new)
`git -c user.name='Christine Ashcreek' -c user.email=dev@null.com -c push.default=simple add "#{new}"             2>/dev/null`
`git -c user.name='Christine Ashcreek' -c user.email=dev@null.com -c push.default=simple add "#{new}.active"      2>/dev/null`
`git -c user.name='Christine Ashcreek' -c user.email=dev@null.com -c push.default=simple add "#{new}.active-uuid" 2>/dev/null`
`git -c user.name='Christine Ashcreek' -c user.email=dev@null.com -c push.default=simple add "#{new}.author"      2>/dev/null`
`git -c user.name='Christine Ashcreek' -c user.email=dev@null.com -c push.default=simple add "#{new}.creator"     2>/dev/null`
`git -c user.name='Christine Ashcreek' -c user.email=dev@null.com -c push.default=simple add "#{new}.stage"       2>/dev/null`
`git -c user.name='Christine Ashcreek' -c user.email=dev@null.com -c push.default=simple commit -m "#{author.gsub(/"/,"'")}"`
`GIT_TERMINAL_PROMPT=0 git push` rescue nil
