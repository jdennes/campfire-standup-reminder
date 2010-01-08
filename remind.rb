
# Add a reminder for our daily standup meetings in our Campfire room
# Campfire and Room classes taken from the official Campfire API
# wrapper: http://developer.37signals.com/campfire/

require 'rubygems'
require 'httparty'
require 'json'
require 'date'

class Campfire
  include HTTParty

  headers 'Content-Type' => 'application/json'

  def self.rooms
    Campfire.get('/rooms.json')["rooms"]
  end

  def self.room(room_id)
    Room.new(room_id)
  end

  def self.user(id)
    Campfire.get("/users/#{id}.json")["user"]
  end
end

class Room
  attr_reader :room_id

  def initialize(room_id)
    @room_id = room_id
  end

  def join
    post 'join'
  end

  def leave
    post 'leave'
  end

  def lock
    post 'lock'
  end

  def unlock
    post 'unlock'
  end

  def message(message)
    send_message message
  end

  def paste(paste)
    send_message paste, 'PasteMessage'
  end

  def play_sound(sound)
    send_message sound, 'SoundMessage'
  end

  def transcript
    get('transcript')['messages']
  end

  private

  def send_message(message, type = 'Textmessage')
    post 'speak', :body => {:message => {:body => message, :type => type}}.to_json
  end

  def get(action, options = {})
    Campfire.get room_url_for(action), options
  end

  def post(action, options = {})
    Campfire.post room_url_for(action), options
  end

  def room_url_for(action)
    "/room/#{room_id}/#{action}.json"
  end
end

# Gets the start time of the next standup meeting, given the hours and
# minutes at which it is held each day
def get_start_time(hours, minutes)
  result = nil
  now = DateTime::now()
  meeting_time_today = DateTime.new(now.year, now.month, now.day, hours, minutes, now.sec, now.of)
  return now > meeting_time_today ? meeting_time_today + 1 : meeting_time_today
end

starting = get_start_time 9, 30
diff = starting - DateTime::now()
hours, mins, secs, ignore_fractions = Date::day_fraction_to_time(diff)

config = YAML.load_file('config.yaml')

#  There won't be standup meetings on the weekend
unless (starting.strftime('%a') == 'Sat' or starting.strftime('%a') == 'Sun')
  reminder = "The next daily stand-up starts at #{starting.strftime('%I:%M %a %d %b, %Y')} (#{hours * 60 + mins} minute#{mins == 1 ? '' : 's'} time)..."

  puts "Connecting to #{config['base_uri']}..."

  Campfire.base_uri config['base_uri']
  Campfire.basic_auth config['api_token'], 'x'
  room = Campfire.room(config['room_id'])
  room.join

  room.message reminder
  room.play_sound 'rimshot'

  puts "Left reminder: #{reminder}"
else
  puts "No standup meetings on the weekend!"
end
