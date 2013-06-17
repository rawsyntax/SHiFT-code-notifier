#!/usr/bin/env ruby
require 'rubygems'
require 'tweetstream'
require 'pony'
require 'yaml'

def has_shift_code?(status, cfg)
  # shift codes typically expire in 3 hours
  three_hours_ago = Time.now.utc - 10800

  code_in_text = status.text =~ /\w{5}-\w{5}-\w{5}-\w{5}-\w{5}/ &&
    status.created_at > three_hours_ago &&
    status.text.downcase.include?(cfg[:shift_type].downcase)

  (code_in_text) ||
    (status.text.downcase.include?("shift code") &&
     status.text.downcase.include?("http"))
end

def watch_twitter(cfg)
  puts "started watching twitter"

  # gearboxsoftware user id 16567106
  # duvalmagic id 8369072
  # echocasts id 846328884
  # example code CBKBB-RSJZH-RTBJJ-3TT3T-5RXZC
  TweetStream::Client.new(username: cfg[:twitter][:user],
                          password: cfg[:twitter][:password]).
    follow(16567106, 8369072, 846328884) do |status|
    # skip replies to user, the API's value of reply_to is inconsistent
    next if status.text =~ /@\S+/

    if has_shift_code?(status, cfg)
      puts "mail: #{status.text}"
      Pony.
        mail({
               :to => cfg[:email][:to],
               :cc => cfg[:email][:cc],
               :via => :smtp,
               :subject => "SHiFT Codes",
               :body => status.text
               :via_options => {
                 :address              => 'smtp.gmail.com',
                 :port                 => '587',
                 :enable_starttls_auto => true,
                 :user_name            => cfg[:email][:user],
                 :password             => cfg[:email][:password],
                 :authentication       => :plain,
                 :domain               => "localhost.localdomain"
               }
             })
    else
      puts "IGNORE #{status.text}"
    end
  end
end

cfg =
  begin
    YAML.load_file("config.yml")
  rescue Errno::ENOENT
    raise "no config.yml found, see config.example.yml"
  end

while(1)
  begin
    watch_twitter(cfg)
  rescue EventMachine::ConnectionError => e
    puts e
    sleep 5
  end
end
