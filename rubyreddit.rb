require 'snoo'
require 'logger'
require 'yaml'
require 'pry'

# Locking trick that uses DATA
DATA.flock(File::LOCK_EX | File::LOCK_NB) or abort "Already Running."
trap("INT", "EXIT")

# log = Logger.new('fuckspam/removals.log', 'weekly')
log = Logger.new(STDOUT)
log.level = Logger::DEBUG

CONFIG = YAML.load_file(File.expand_path('../rubyreddit.yaml', __FILE__))

reddit = Snoo::Client.new useragent: "Paradox's police bot"

reddit.auth CONFIG['modhash'], CONFIG['cookies']

shit, spam = [[],[]]

CONFIG['subreddits'].each do |sr, v|
  retried = nil
  begin
    log.debug "Getting new for #{sr}"
    listing = reddit.get_listing(subreddit: sr, page: 'new', sort: 'new', limit: CONFIG['limit'])['data']['children']
    sleep 2
    log.debug "Getting hot for #{sr}"
    listing += reddit.get_listing(subreddit: sr, limit: CONFIG['limit'])['data']['children']
    sleep 2
    log.debug "Getting modqueue for #{sr}"
    listing += reddit.get_modqueue(sr)['data']['children']
    sleep 2
    log.debug "Getting comments for #{sr}"
    comments = reddit.get_comments(subreddit: sr, limit: 1000)['data']['children']
    sleep 2
  rescue => e
    if retried.nil?
      retried = true
      retry
    else
      log.error e
      retried = nil
      next
    end
  end
  listing.uniq!

  # Users
  if CONFIG['subreddits'][sr]['badusers']
    badusers = CONFIG['subreddits'][sr]['badusers'].compact.map { |d| Regexp.new(d, true)}

    shit += listing.select do |thing|
      badusers.index { |r| thing['data']['author'] =~ r} unless ( thing['data']['approved_by'] or (thing['data']['banned_by'] != true && thing['data']['banned_by']))
    end

    shit += comments.select do |thing|
      badusers.index { |r| thing['data']['author'] =~ r} unless ( thing['data']['approved_by'] or (thing['data']['banned_by'] != true && thing['data']['banned_by']))
    end

    listing -= shit
    comments -= shit
  end

  listing.reject! do |thing|
    (thing['kind'] == 't1') or (thing['data']['is_self'])
  end

  # Domains
  if CONFIG['subreddits'][sr]['domains']
    domains = CONFIG['subreddits'][sr]['domains'].compact.map { |d| Regexp.new(d, true)}

    if CONFIG['subreddits'][sr]['mode'] && CONFIG['subreddits'][sr]['mode'] == 'whitelist'
      spam += listing.select do |thing|
        domains.index { |r| thing['data']['domain'] =~ r }.nil? unless ( thing['data']['approved_by'] or (thing['data']['banned_by'] != true && thing['data']['banned_by']))
      end
    else
      spam += listing.select do |thing|
        (! domains.index { |r| thing['data']['domain'] =~ r }.nil? ) unless ( thing['data']['approved_by'] or (thing['data']['banned_by'] != true && thing['data']['banned_by']))
      end
    end
    listing -= spam
  end

  # Words
  if CONFIG['subreddits'][sr]['badwords']
    badwords = CONFIG['subreddits'][sr]['badwords'].compact.map { |d| Regexp.new(d, true)}

    # This is separate from the badusers above because a baduser should take precedence over the self-post allow system
    # It will probably need to be changed later
    shit += listing.select do |thing|
      badwords.index { |r| thing['data']['title'] =~ r} unless ( thing['data']['approved_by'] or (thing['data']['banned_by'] != true && thing['data']['banned_by']))
    end
  end

  # Comments
  if CONFIG['subreddits'][sr]['badcomments']
    badcomments = CONFIG['subreddits'][sr]['badcomments'].compact.map { |d| Regexp.new(d, true)}
    shit += comments.select do |thing|
      badcomments.index { |r| thing['data']['body'] =~ r} unless ( thing['data']['approved_by'] or (thing['data']['banned_by'] != true && thing['data']['banned_by']))
    end
  end
end

shit -= spam

spam.uniq!

spam.each do |thing|
  log.info "Spamming #{thing['data']['title']} by #{thing['data']['author']} on #{thing['data']['subreddit']} (#{thing['data']['domain']}) [#{thing['data']['name']}]"
  reddit.remove(thing['data']['name'], true) rescue nil
  sleep 2
end

shit.uniq!

shit.each do |thing|
  if thing['kind'] == 't3'
    log.info "Removing #{thing['data']['title']} by #{thing['data']['author']} (#{thing['data']['domain']}) [#{thing['data']['name']}]"
  elsif thing['kind'] == 't1'
    log.info "Removing comment by #{thing['data']['author']} from #{thing['data']['link_id']} (r/#{thing['data']['subreddit']})"
  end
  reddit.remove(thing['data']['name'], false) rescue nil
  sleep 2
end
__END__
DO NOT DELETE: Used for locking
