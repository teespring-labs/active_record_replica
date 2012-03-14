active_record_slave
===================

* http://github.com/ClarityServices/active_record_slave

## Introduction

active_record_slave allows all database reads to go to a slave while ensuring
that all writes go to the master database. Also, active_record_slave ensures that
any reads that are performed in a transaction will always go to the master
database to ensure data consistency.

## Features

* Redirecting reads to a single slave database
* Supports all Rails 3 read apis, including dynamic finders, AREL, and ActiveRecord::Base.select
* Transaction aware. Detects when a query is inside of a transaction and sends
  those reads to the master
* Lightweight footprint
* No overhead when a slave is not configured
* Minimal overhead when redirecting reads to the slave
* Connection Pools to both databases are retained and maintained independently by ActiveRecord
* The master and slave databases do not have to be of the same type.
  For example one can be MySQL and the other Oracle if required.
* Debug logs include 'Slave: ' prefix to indicate which SQL statements are going
  to the slave database

### Example showing Slave redirected read
    r = Role.where(:name => "manager").first
    r.description = 'Manager'
    r.save!

Log file output:

    03-13-12 05:56:05 pm,[2608],b[0],[0],  Slave: Role Load (3.0ms)  SELECT `roles`.* FROM `roles` WHERE `roles`.`name` = 'manager' LIMIT 1
    03-13-12 05:56:22 pm,[2608],b[0],[0],  AREL (12.0ms)  UPDATE `roles` SET `description` = 'Manager' WHERE `roles`.`id` = 5

### Example showing how reads within a transaction go to the master
    Role.transaction do
      r = Role.where(:name => "manager").first
      r.description = 'Manager'
      r.save!
    end

Log file output:

    03-13-12 06:02:09 pm,[2608],b[0],[0],  Role Load (2.0ms)  SELECT `roles`.* FROM `roles` WHERE `roles`.`name` = 'manager' LIMIT 1
    03-13-12 06:02:09 pm,[2608],b[0],[0],  AREL (2.0ms)  UPDATE `roles` SET `description` = 'Manager' WHERE `roles`.`id` = 4

## Requirements

* Rails 3 or greater

May also work with Rails 2. Anyone want to give it a try and let me know?
Happy to make it work with Rails 2 if anyone needs it

## Note

ActiveRecord::Base.execute is commonly used to perform custom SQL calls against
the database that bypasses ActiveRecord. It is necessary to replace these calls
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

    development:
      database: clarity_development
      username: root
      password:
      encoding: utf8
      adapter:  mysql
      host:     127.0.0.1
      pool:     20
      slave:
        database: clarity_development_replica
        username: root
        password:
        encoding: utf8
        adapter:  mysql
        host:     127.0.0.1
        pool:     20

Sometimes it is useful to turn on slave reads per host, for example to activate
slave reads only on the linux host 'batch':
    development:
      database: clarity_development
      username: root
      password:
      encoding: utf8
      adapter:  mysql
      host:     127.0.0.1
      pool:     20
    <% if `hostname`.strip == 'batch' %>
      slave:
        database: clarity_development_replica
        username: root
        password:
        encoding: utf8
        adapter:  mysql
        host:     127.0.0.1
        pool:     20
    <% end %>

## Possible Future Enhancements

* Support multiple slaves (ask for it by submitting a ticket)

Meta
----

* Code: `git clone git://github.com/ClarityServices/active_record_slave.git`
* Home: <https://github.com/ClarityServices/active_record_slave>
* Bugs: <https://github.com/ClarityServices/active_record_slave/issues>
* Gems: <http://rubygems.org/gems/active_record_slave>

This project uses [Semantic Versioning](http://semver.org/).

Authors
-------

Reid Morrison :: reidmo@gmail.com :: @reidmorrison

License
-------

Copyright 2012 Clarity Services, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
