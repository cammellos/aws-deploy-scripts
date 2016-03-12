
target = ARGV[0]
directory = ARGV[1] || '.'


build_command = "docker build -t #{target}:latest #{directory}"
push_command = "docker push #{target}"

system(build_command)
