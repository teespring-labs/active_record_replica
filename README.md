# Active Record Slave
[![Gem Version](https://img.shields.io/gem/v/active_record_slave.svg)](https://rubygems.org/gems/active_record_slave) [![Build Status](https://travis-ci.org/rocketjob/active_record_slave.svg?branch=master)](https://travis-ci.org/rocketjob/active_record_slave) [![Downloads](https://img.shields.io/gem/dt/active_record_slave.svg)](https://rubygems.org/gems/active_record_slave) [![License](https://img.shields.io/badge/license-Apache%202.0-brightgreen.svg)](http://opensource.org/licenses/Apache-2.0) ![](https://img.shields.io/badge/status-Production%20Ready-blue.svg) [![Gitter chat](https://img.shields.io/badge/IRC%20(gitter)-Support-brightgreen.svg)](https://gitter.im/rocketjob/support)

Redirect ActiveRecord (Rails) reads to slave databases while ensuring all writes go to the master database.

* https://github.com/rocketjob/active_record_slave

## Introduction

active_record_slave redirects all database reads to slave instances while ensuring
that all writes go to the master database. active_record_slave ensures that
any reads that are performed within a database transaction are by default directed to the master
database to ensure data consistency.

## Status

Production Ready. Actively used in large production environments.

## Features

* Redirecting reads to a single slave database.
* Works with any database driver that works with ActiveRecord.
* Supports all Rails 3, 4, or 5 read apis.
    * Including dynamic finders, AREL, and ActiveRecord::Base.select.
    * **NOTE**: In Rails 3 and 4, QueryCache is only enabled for BaseConnection by default. In Rails 5, it's enabled for all connections. [(PR)](https://github.com/rails/rails/pull/28869)
* Transaction aware
    * Detects when a query is inside of a transaction and sends those reads to the master by default.
    * Can be configured to send reads in a transaction to slave databases.
* Lightweight footprint.
* No overhead whatsoever when a slave is _not_ configured.
* Negligible overhead when redirecting reads to the slave.
* Connection Pools to both databases are retained and maintained independently by ActiveRecord.
* The master and slave databases do not have to be of the same type.
    * For example Oracle could be the master with MySQL as the slave database.
* Debug logs include a prefix of `Slave: ` to indicate which SQL statements are going
  to the slave database.

### Example showing Slave redirected read

```ruby
# Read from the slave database
r = Role.where(name: 'manager').first
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
  r = Role.where(name: 'manager').first
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
  r = Role.where(name: 'manager').first
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

## Transactions

By default ActiveRecordSlave detects when a call is inside a transaction and will
send all reads to the _master_ when a transaction is active.

It is now possible to send reads to database slaves and ignore whether currently
inside a transaction:

In file config/application.rb:

```ruby
# Read from slave even when in an active transaction
config.active_record_slave.ignore_transactions = true
```

It is important to identify any code in the application that depends on being
able to read any changes already part of the transaction, but not yet committed
and wrap those reads with `ActiveRecordSlave.read_from_master`

```ruby
Inquiry.transaction do
  # Create a new inquiry
  Inquiry.create
  
  # The above inquiry is not visible yet if already in a Rails transaction.
  # Use `read_from_master` to ensure it is included in the count below:
  ActiveRecordSlave.read_from_master do
    count = Inquiry.count
  end

end
```

## Note

Active Record Slave is a very simple layer that inserts itself into the call chain whenever a slave is configured.
By observation we noticed that all reads are made to a select set of methods and 
all writes are made directly to one method: `execute`.

Using this observation Active Record Slave only needs to intercept calls to the known select apis: 
* select_all
* select_one
* select_rows
* select_value
* select_values

Calls to the above methods are redirected to the slave active record model `ActiveRecordSlave::Slave`. 
This model is 100% managed by the regular Active Record mechanisms such as connection pools etc.

This lightweight approach ensures that all calls to the above API's are redirected to the slave without impacting:
* Transactions
* Writes
* Any SQL calls directly to `execute`

One of the limitations with this approach is that any code that performs a query by calling `execute` direct will not
be redirected to the slave instance. In this case replace the use of `execute` with one of the the above select methods. 


## Note when using `dependent: destroy`

When performing in-memory only model assignments Active Record will create a transaction against the master even though
the transaction may never be used.

Even though the transaction is unused it sends the following messages to the master database:
~~~
SET autocommit=0
commit
SET autocommit=1
~~~ 

This will impact the master database if sufficient calls are made, such as in batch workers.

For Example:

~~~ruby
class Parent < ActiveRecord::Base
  has_one :child, dependent: :destroy
end

class Child < ActiveRecord::Base
  belongs_to :parent
end

# The following code will create an unused transaction against the master, even when reads are going to slaves:
parent = Parent.new
parent.child = Child.new
~~~

If the `dependent: :destroy` is removed it no longer creates a transaction, but it also means dependents are not
destroyed when a parent is destroyed.

For this scenario when we are 100% confident no writes are being performed the following can be performed to 
ignore any attempt Active Record makes at creating the transaction:

~~~ruby
ActiveRecordSlave.skip_transactions do
  parent = Parent.new
  parent.child = Child.new
end
~~~

To help identify any code within a block that is creating transactions, wrap the code with 
`ActiveRecordSlave.block_transactions` to make it raise an exception anytime a transaction is attempted:

~~~ruby
ActiveRecordSlave.block_transactions do
  parent = Parent.new
  parent.child = Child.new
end
~~~

## Install

Add to `Gemfile`

```ruby
gem 'active_record_slave'
```

Run bundler to install:

```
bundle
```

Or, without Bundler:

```
gem install active_record_slave
```

## Configuration

To enable slave reads for any environment just add a _slave:_ entry to database.yml
along with all the usual ActiveRecord database configuration options.

For Example:

```yaml
production:
  database: production
  username: username
  password: password
  encoding: utf8
  adapter:  mysql
  host:     master1
  pool:     50
  slave:
    database: production
    username: username
    password: password
    encoding: utf8
    adapter:  mysql
    host:     slave1
    pool:     50
```

Sometimes it is useful to turn on slave reads per host, for example to activate
slave reads only on the linux host 'batch':

```yaml
production:
  database: production
  username: username
  password: password
  encoding: utf8
  adapter:  mysql
  host:     master1
  pool:     50
<% if `hostname`.strip == 'batch' %>
  slave:
    database: production
    username: username
    password: password
    encoding: utf8
    adapter:  mysql
    host:     slave1
    pool:     50
<% end %>
```

If there are multiple slaves, it is possible to randomly select a slave on startup
to balance the load across the slaves:

```yaml
production:
  database: production
  username: username
  password: password
  encoding: utf8
  adapter:  mysql
  host:     master1
  pool:     50
  slave:
    database: production
    username: username
    password: password
    encoding: utf8
    adapter:  mysql
    host:     <%= %w(slave1 slave2 slave3).sample %>
    pool:     50
```

Slaves can also be assigned to specific hosts by using the hostname:

```yaml
production:
  database: production
  username: username
  password: password
  encoding: utf8
  adapter:  mysql
  host:     master1
  pool:     50
  slave:
    database: production
    username: username
    password: password
    encoding: utf8
    adapter:  mysql
    host:     <%= `hostname`.strip == 'app1' ? 'slave1' : 'slave2' %>
    pool:     50
```

## Set master as default for Read

The default behavior can also set to read/write operations against master database.

Create an initializer file config/initializer/active_record_slave.rb to force read from master:

```yaml
    ActiveRecordSlave.read_from_master!
```

Then use this method and supply block to read from the slave database:

```yaml
ActiveRecordSlave.read_from_slave do
   User.count
end
```

## Dependencies

See [.travis.yml](https://github.com/reidmorrison/active_record_slave/blob/master/.travis.yml) for the list of tested Ruby platforms

## Versioning

This project uses [Semantic Versioning](http://semver.org/).

## Author

[Reid Morrison](https://github.com/reidmorrison) :: @reidmorrison
