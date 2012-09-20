#!/usr/bin/env ruby

#Seting variables and such:
require 'fileutils'
require 'mail'

#Setting time variables
this_month = Time.now.month.to_s
last_month = (Time.now.month - 1).to_s
year = Time.now.year

if this_month == 1
	last_month_year = (year - 1).to_s
	last_month = 12.to_s
else
	last_month_year = year
end

#Setting path, dir, and file variables
#Path is the dir where the script and txt files live and will be where the monthly results dirs are made.
path = "/path/to/dir"

old_data_exists = Dir.glob("#{path}/#{last_month}-#{last_month_year}/*")
current_data_exists = Dir.glob("#{path}/#{this_month}-#{year}/*")
last_month_dir = "#{path}/#{last_month}-#{last_month_year}"
this_month_dir = "#{path}/#{this_month}-#{year}"
different_files = []

#Setting mail options and emails, use either smtpoptions or the sendmail one:
smtpoptions = { :address              => "mail.someserver.org",
            :port                 => 25,
            :domain               => 'someserver.org',
            :user_name            => 'name@someserver.org',
            :password             => 'goodpassword',
            :authentication       => 'plain',
            :enable_starttls_auto => false  }
Mail.defaults do
  delivery_method :smtp,smtpoptions
#  delivery_method :sendmail
end
#The other mails setup had to be moved in the code after the 
#file attachments are made or it errors out.
no_result_mail = Mail.new do
   from    'name@someserver.org'
   to      'name@someserver.org'
   subject 'Monthly scan results'
   body    'Last months results were not found. Manually look over the results.'
end

#Setting nmap data variables
#datafile must be in "filename ipaddress" format, one pair per line
datafile = "test.txt"
scandata = File.readlines("#{datafile}")
#Use your nmapfu to set whatever you want here:
nmap_scan_ops = "-sV -v -sS" 
#Note: if you use ports don't have a space after the letter or the numbers get moved to the end of the command and if fails.
#-PS80,443 for example, NOT -PS 80,443
nmap_disc_ops = "-PS21,22,25,53,80,88,135,137,138,139,443,445,6000,513,514,512,5900,5901,8001,8006,3389,5631,65301,5938,8200,1417,1418,1419,1420"
#Warning: The script uses all three file, don't change nmap_out unless you are editing
#the script and know what you are doing!
nmap_out = "-oA"

#Getting to work:

#Setting up dir for new data, moving existing files to an old dir if they already exist
if current_data_exists.empty?
	FileUtils.mkdir("#{this_month_dir}")
else
	File.directory?("#{this_month_dir}/old") ? "Old dir already exists, bad month?" : FileUtils.mkdir("#{this_month_dir}/old")
	FileUtils.mv Dir.glob("#{path}/#{this_month}-#{year}/*nmap"), "#{this_month_dir}/old"
	FileUtils.mv Dir.glob("#{path}/#{this_month}-#{year}/*xml"), "#{this_month_dir}/old"
	FileUtils.mv Dir.glob("#{path}/#{this_month}-#{year}/*txt"), "#{this_month_dir}/old"
end

#Doing the nmap scan
scandata.each { |line| %x{nmap #{nmap_scan_ops} #{nmap_disc_ops} #{nmap_out} #{this_month_dir}/#{line}}}	

#Dealing with the results
unless old_data_exists.empty?
	results_files = Dir.glob("#{this_month_dir}/*.nmap")
	results_files.each do |line|
		filename = line.split(/\//).reverse[0]
		gfilename = filename.gsub("nmap", "gnmap")
		#FileUtils.identical?("#{this_month_dir}/#{filename}", "#{last_month_dir}/#{filename}") ? "No change" : different_files << filename
		#Dates and times made identical? not work on real data.
		#Instead looked for changes in up and open in the gnmap file.
		#And added an ndiff attachment to make sure nothing was missed.
		o = File.read("#{last_month_dir}/#{gfilename}").scan(/.{10}up|.{10}open/).sort
		n = File.read("#{this_month_dir}/#{gfilename}").scan(/.{10}up|.{10}open/).sort
		o == n ? "No Change." : different_files << filename
	end
	xfiles = Dir.glob("#{this_month_dir}/*.xml")
	xfiles.each do |line|
		xfilename = line.split(/\//).reverse[0]
		%x{ndiff #{this_month_dir}/#{xfilename} #{last_month_dir}/#{xfilename} >>#{this_month_dir}/ndiff.txt} 
	end
else
no_result_mail.deliver!
exit
end

unless different_files.empty?
	monthly_file = File.new("#{this_month_dir}/monthlyreport.txt", "a")
	monthly_file.puts "Nmap Scan results for #{this_month}, #{year}."
	monthly_file.puts "Different results from last month only."
	different_files.each do |line|
		monthly_file.puts "----------------Last Month's #{line}.---------------"
		monthly_file.puts File.readlines("#{last_month_dir}/#{line}")
		monthly_file.puts "---------------This Month's #{line}.----------------"
		monthly_file.puts File.readlines("#{this_month_dir}/#{line}")
	end
	monthly_file.puts "-----------End of changes.-----------"
	monthly_file.close
	result_mail = Mail.new do
   		from    'name@someserver.org'
   		to      'name@someserver.org'
   		subject 'Monthly Scan Results'
   		body    File.read("#{path}/resultsmail.txt")
  		add_file "#{this_month_dir}/monthlyreport.txt"
		add_file "#{this_month_dir}/ndiff.txt"
	end
	result_mail.deliver!
else
no_change_mail = Mail.new do
   from    'name@someserver.org'
   to      'name@someserver.org'
   subject 'Monthy Scan Results'
   body    File.read("#{path}/nochangemail.txt")
	add_file "#{this_month_dir}/ndiff.txt"
end
no_change_mail.deliver!
end
