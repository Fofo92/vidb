require 'securerandom'
require 'json'
require 'fileutils'

abort 'Environnement de production requis' unless Rails.env.production?
url = ARGV.fetch(0).delete_suffix('/')
path = EncoderProjects::Settings::PATH
existing = File.file?(path) ? EncoderProjects::Settings.read : {}
user_id = ARGV[1] || existing['user_id']
abort 'Plusieurs comptes vidb : précise USER_ID à la commande d’installation.' if !user_id && User.count != 1
user = user_id ? User.find(Integer(user_id)) : User.all.sole
data = { 'url' => url, 'token' => existing.fetch('token', SecureRandom.hex(32)), 'user_id' => user.id }
EncoderProjects::Settings.validate!(data)
FileUtils.mkdir_p(File.dirname(path), mode: 0o700)
temporary = "#{path}.#{Process.pid}.tmp"
File.open(temporary, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| file.write(JSON.generate(data)) }
File.rename(temporary, path)
puts "Passerelle configurée pour le compte vidb n° #{user.id} ; secret conservé localement."
