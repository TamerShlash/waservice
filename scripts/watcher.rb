#! /usr/bin/ruby

pid_path = File.expand_path(File.join(File.dirname(__FILE__),'..','tmp','listener.pid'))
listener_path = File.expand_path(File.join(File.dirname(__FILE__),'..','yowsup','listener.py'))

if File.exists? pid_path
  pid = File.open(pid_path,'r') {|f| f.read }
  alive =begin
    Process.getpgid pid.to_i
    true
  rescue Errno::ESRCH
    false
  end
  unless alive
    pid = fork do
#      Process.daemon(true,false)
      $stdout.reopen("/dev/null", "w")
      $stderr.reopen("/dev/null", "w")
      exec "/usr/bin/python #{listener_path}"
    end
    Process.detach pid # This will make the forked process not child of the current one
    File.open(pid_path, 'w') { |file| file.write(pid.to_s) }
    puts "[#{Time.now}] watcher: Relaunched the listener | pid=#{pid}"
  end
else
  pid = fork do
#    Process.daemon(true,false)
    $stdout.reopen("/dev/null", "w")
    $stderr.reopen("/dev/null", "w")
    exec "/usr/bin/python #{listener_path}"
  end
  Process.detach pid
  File.open(pid_path, 'w') { |file| file.write(pid.to_s) }
  puts "[#{Time.now}] watcher: Started the listener | pid=#{pid}"
end