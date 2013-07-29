require 'snoo'
require 'highline/import'
task :default => [:config]

task :config do
  @hl = HighLine.new

  puts @hl.color("Enter your reddit username and password", :bold, :cyan)
  puts @hl.color("-" * @hl.output_cols, :bold, :cyan)
  username = @hl.ask('Username: ')
  
  password = @hl.ask('Password: ') { |x| x.echo = "*" }
  
  @s = Snoo::Client.new(username: username, password: password)
  
  puts @hl.color("Copy and paste the following to the top of your ", :bold, :cyan) + @hl.color("rubyreddit.yml", :bold, :green) + @hl.color(" file:", :bold, :cyan)
  
  puts "modhash: #{@s.modhash}"
  puts "cookies: #{@s.cookies.split(/(reddit_session=.*?);/)[1]}"

end