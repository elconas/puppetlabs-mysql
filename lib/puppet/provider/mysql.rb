class Puppet::Provider::Mysql < Puppet::Provider

  # Without initvars commands won't work.
  initvars
  commands :mysql      => 'mysql'
  commands :mysqld     => 'mysqld'
  commands :mysqladmin => 'mysqladmin'

  # Optional defaults file
  def self.defaults_file
    if File.file?("#{Facter.value(:root_home)}/.my.cnf")
      "--defaults-extra-file=#{Facter.value(:root_home)}/.my.cnf"
    else
      nil
    end
  end

  def self.mysqld_version
    # we cache the result ... 
    # note: be prepared for '5.7.6-rc-log' etc results
    #       versioncmp detects 5.7.6-log to be newer then 5.7.6
    #       this is why we need the trimming.
    return @mysqld_version_string.scan(/\d+\.\d+\.\d+/).first unless @mysqld_version_string.nil?
    @mysqld_version_string = mysqld(['-V'].compact)
    return @mysqld_version_string.scan(/\d+\.\d+\.\d+/).first unless @mysqld_version_string.nil?
    nil
  end

  def mysqld_version
    self.class.mysqld_version
  end

  def defaults_file
    self.class.defaults_file
  end

  def self.users
    mysql([defaults_file, '-NBe', "SELECT CONCAT(User, '@',Host) AS User FROM mysql.user"].compact).split("\n")
  end

  # Take root@localhost and munge it to 'root'@'localhost'
  def self.cmd_user(user)
    "'#{user.sub('@', "'@'")}'"
  end

  # Take root.* and return ON `root`.*
  def self.cmd_table(table)
    table_string = ''

    # We can't escape *.* so special case this.
    if table == '*.*'
      table_string << '*.*'
    # Special case also for PROCEDURES
    elsif table.start_with?('PROCEDURE ')
      table_string << table.sub(/^PROCEDURE (.*)(\..*)/, 'PROCEDURE `\1`\2')
    else
      table_string << table.sub(/^(.*)(\..*)/, '`\1`\2')
    end
    table_string
  end

  def self.cmd_privs(privileges)
    if privileges.include?('ALL')
      return 'ALL PRIVILEGES'
    else
      priv_string = ''
      privileges.each do |priv|
        priv_string << "#{priv}, "
      end
    end
    # Remove trailing , from the last element.
    priv_string.sub(/, $/, '')
  end

  # Take in potential options and build up a query string with them.
  def self.cmd_options(options)
    option_string = ''
    options.each do |opt|
      if opt == 'GRANT'
        option_string << ' WITH GRANT OPTION'
      end
    end
    option_string
  end

end
