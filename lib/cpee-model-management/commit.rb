models = ARGV[0]
new = ARGV[1]
author = ARGV[2]

Dir.chdir(File.join(models,File.dirname(new)))
new = File.basename(new)
`git add "#{new}" 2>/dev/null`
`git add "#{new}.active" 2>/dev/null`
`git add "#{new}.active-uuid" 2>/dev/null`
`git add "#{new}.author" 2>/dev/null`
`git add "#{new}.creator" 2>/dev/null`
`git add "#{new}.stage" 2>/dev/null`
`git commit -m "#{author.gsub(/"/,"'")}"`
`git push` rescue nil
