active_record_slave [![Build Status](https://secure.travis-ci.org/reidmorrison/active_record_slave.png?branch=master)](http://travis-ci.org/reidmorrison/active_record_slave)
===================

ActiveRecord drop-in solution to efficiently redirect reads to slave databases

* http://github.com/reidmorrison/active_record_slave

## Introduction

active_record_slave allows all database reads to go to a slave while ensuring
that all writes go to the master database. Also, active_record_slave ensures that
any reads that are performed in a transaction will always go to the master
database to ensure data consistency.

## Features

* Redirecting reads to a single slave database
* Works with any database driver that works with ActiveRecord
* Supports all Rails 3 read apis, including dynamic finders, AREL, and ActiveRecord::Base.select
* Transaction aware. Detects when a query is inside of a transaction and sends
  those reads to the master
* Lightweight footprint
* No overhead whatsoever when a slave is not configured
* Negligible overhead when redirecting reads to the slave
* Connection Pools to both databases are retained and maintained independently by ActiveRecord
* The master and slave databases do not have to be of the same type.
  For example one can be MySQL and the other Oracle if required.
* Debug logs include a prefix of 'Slave: ' to indicate which SQL statements are going
  to the slave database

### Example showing Slave redirected read

```ruby
# Read from the slave database
r = Role.where(:name => "manager").first
r.description = 'Manager'

# Save changes back to the master database
r.save!
```

Log file output:

    03-13-12 05:56:05 pm,[2608],b[0],[0],  Slave: Role Load (3.0ms)  SELECT `roles`.* FROM `roles` WHERE `roles`.`name` = 'manager' LIMIT 1
    03-13-12 05:56:22 pm,[2608],b[0],[0],  AREL (12.0ms)  UPDATE `roles` SET `description` = 'Manager' WHERE `roles`.`id` = 5

### Example showing how reads within a transaction go to the master

```ruby
Role.transaction do
  r = Role.where(:name => "manager").first
  r.description = 'Manager'
  r.save!
end
```

Log file output:

    03-13-12 06:02:09 pm,[2608],b[0],[0],  Role Load (2.0ms)  SELECT `roles`.* FROM `roles` WHERE `roles`.`name` = 'manager' LIMIT 1
    03-13-12 06:02:09 pm,[2608],b[0],[0],  AREL (2.0ms)  UPDATE `roles` SET `description` = 'Manager' WHERE `roles`.`id` = 4

### Forcing a read against the master

Sometimes it is necessary to read from the master:

```ruby
ActiveRecordSlave.read_from_master do
  r = Role.where(:name => "manager").first
end
```

## Usage Notes

### delete_all

Delete all executes against the master database since it is only a delete:

```
D, [2012-11-06T19:47:29.125932 #89772] DEBUG -- :   SQL (1.0ms)  DELETE FROM "users"
```

### destroy_all

First performs a read against the slave database and then deletes the corresponding
data from the master

```
D, [2012-11-06T19:43:26.890674 #89002] DEBUG -- :   Slave: User Load (0.1ms)  SELECT "users".* FROM "users"
D, [2012-11-06T19:43:26.890972 #89002] DEBUG -- :    (0.0ms)  begin transaction
D, [2012-11-06T19:43:26.891667 #89002] DEBUG -- :   SQL (0.4ms)  DELETE FROM "users" WHERE "users"."id" = ?  [["id", 3]]
D, [2012-11-06T19:43:26.892697 #89002] DEBUG -- :    (0.9ms)  commit transaction
```

## Dependencies

* Tested on Rails 3 and Rails 4

See [.travis.yml](https://github.com/reidmorrison/active_record_slave/.travis.yml) for the list of tested Ruby platforms

## Note

ActiveRecord::Base.execute is sometimes used to perform custom SQL calls against
the database to bypass ActiveRecord. It is necessary to replace these calls
with the standard ActiveRecord::Base.select call for them to be picked up by
active_record_slave and redirected to the slave.

This is because ActiveRecord::Base.execute can also be used for database updates
which we do not want redirected to the slave

## Install

  gem install active_record_slave

## Configuration

To enable slave reads for any environment just add a _slave:_ entry to database.yml
along with all the usual ActiveRecord database configuration options.

For Example:

```yaml
development:
  database: myapp_development
  username: root
  password:
  encoding: utf8
  adapter:  mysql
  host:     127.0.0.1
  pool:     20
  slave:
    database: myapp_development_replica
    username: root
    password:
    encoding: utf8
    adapter:  mysql
    host:     127.0.0.1
    pool:     20
```

Sometimes it is useful to turn on slave reads per host, for example to activate
slave reads only on the linux host 'batch':

```yaml
development:
  database: myapp_development
  username: root
  password:
  encoding: utf8
  adapter:  mysql
  host:     127.0.0.1
  pool:     20
<% if `hostname`.strip == 'batch' %>
  slave:
    database: myapp_development_replica
    username: root
    password:
    encoding: utf8
    adapter:  mysql
    host:     127.0.0.1
    pool:     20
<% end %>
```

## Possible Future Enhancements

* Support for multiple slaves (ask for it by submitting an issue)

Meta
----

* Code: `git clone git://github.com/reidmorrison/active_record_slave.git`
* Home: <https://github.com/reidmorrison/active_record_slave>
* Bugs: <https://github.com/reidmorrison/active_record_slave/issues>
* Gems: <http://rubygems.org/gems/active_record_slave>

This project uses [Semantic Versioning](http://semver.org/).

Authors
-------

Reid Morrison :: reidmo@gmail.com :: @reidmorrison

License
-------

Copyright 2012, 2013, 2014 Reid Morrison

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
