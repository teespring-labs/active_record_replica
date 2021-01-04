# Active Record Replica
[![Gem Version](https://img.shields.io/gem/v/active_record_replica.svg)](https://rubygems.org/gems/active_record_replica)
[![Build Status](https://travis-ci.org/teespring/active_record_replica.svg?branch=master)](https://travis-ci.org/teespring/active_record_replica)
[![License](https://img.shields.io/badge/license-Apache%202.0-brightgreen.svg)](http://opensource.org/licenses/Apache-2.0)
![](https://img.shields.io/badge/status-Production%20Ready-blue.svg)

Redirect ActiveRecord (Rails) reads to replica databases while ensuring all writes go to the primary database.

## Status
This is a slight modification of Rocket Job's original library, simply renaming it from `active_record_slave` to `active_record_replica`.

In order to more clearly distinguish the library from `active_record_slave`, we also incremented the major version – it is, however, functionally equivalent.

## Introduction

`active_record_replica` redirects all database reads to replica instances while ensuring
that all writes go to the primary database. `active_record_replica` ensures that
any reads that are performed within a database transaction are by default directed to the primary
database to ensure data consistency.

## Status

Production Ready. Actively used in large production environments.

## Features

* Redirecting reads to a single replica database.
* Works with any database driver that works with ActiveRecord.
* Supports all Rails 3, 4, or 5 read apis.
    * Including dynamic finders, AREL, and ActiveRecord::Base.select.
    * **NOTE**: In Rails 3 and 4, QueryCache is only enabled for BaseConnection by default. In Rails 5, it's enabled for all connections. [(PR)](https://github.com/rails/rails/pull/28869)
* Transaction aware
    * Detects when a query is inside of a transaction and sends those reads to the primary by default.
    * Can be configured to send reads in a transaction to replica databases.
* Lightweight footprint.
* No overhead whatsoever when a replica is _not_ configured.
* Negligible overhead when redirecting reads to the replica.
* Connection Pools to both databases are retained and maintained independently by ActiveRecord.
* The primary and replica databases do not have to be of the same type.
    * For example Oracle could be the primary with MySQL as the replica database.
* Debug logs include a prefix of `Replica: ` to indicate which SQL statements are going
  to the replica database.

### Example showing Replica redirected read

```ruby
# Read from the replica database
r = Role.where(name: 'manager').first
r.description = 'Manager'

# Save changes back to the primary database
r.save!
```

Log file output:

    03-13-12 05:56:05 pm,[2608],b[0],[0],  Replica: Role Load (3.0ms)  SELECT `roles`.* FROM `roles` WHERE `roles`.`name` = 'manager' LIMIT 1
    03-13-12 05:56:22 pm,[2608],b[0],[0],  AREL (12.0ms)  UPDATE `roles` SET `description` = 'Manager' WHERE `roles`.`id` = 5

### Example showing how reads within a transaction go to the primary

~~~ruby
Role.transaction do
  r = Role.where(name: 'manager').first
  r.description = 'Manager'
  r.save!
end
~~~

Log file output:

    03-13-12 06:02:09 pm,[2608],b[0],[0],  Role Load (2.0ms)  SELECT `roles`.* FROM `roles` WHERE `roles`.`name` = 'manager' LIMIT 1
    03-13-12 06:02:09 pm,[2608],b[0],[0],  AREL (2.0ms)  UPDATE `roles` SET `description` = 'Manager' WHERE `roles`.`id` = 4

### Forcing a read against the primary

Sometimes it is necessary to read from the primary:

~~~ruby
ActiveRecordReplica.read_from_primary do
  r = Role.where(name: 'manager').first
end
~~~

## Usage Notes

### delete_all

Delete all executes against the primary database since it is only a delete:

~~~
D, [2012-11-06T19:47:29.125932 #89772] DEBUG -- :   SQL (1.0ms)  DELETE FROM "users"
~~~

### destroy_all

First performs a read against the replica database and then deletes the corresponding
data from the primary

~~~
D, [2012-11-06T19:43:26.890674 #89002] DEBUG -- :   Replica: User Load (0.1ms)  SELECT "users".* FROM "users"
D, [2012-11-06T19:43:26.890972 #89002] DEBUG -- :    (0.0ms)  begin transaction
D, [2012-11-06T19:43:26.891667 #89002] DEBUG -- :   SQL (0.4ms)  DELETE FROM "users" WHERE "users"."id" = ?  [["id", 3]]
D, [2012-11-06T19:43:26.892697 #89002] DEBUG -- :    (0.9ms)  commit transaction
~~~

## Transactions

By default Active Record Replica detects when a call is inside a transaction and will
send all reads to the _primary_ when a transaction is active.

It is now possible to send reads to database replicas and ignore whether currently
inside a transaction:

In file config/application.rb:

~~~ruby
# Read from replica even when in an active transaction
config.active_record_replica.ignore_transactions = true
~~~

It is important to identify any code in the application that depends on being
able to read any changes already part of the transaction, but not yet committed
and wrap those reads with `ActiveRecordReplica.read_from_primary`

~~~ruby
Inquiry.transaction do
  # Create a new inquiry
  Inquiry.create

  # The above inquiry is not visible yet if already in a Rails transaction.
  # Use `read_from_primary` to ensure it is included in the count below:
  ActiveRecordReplica.read_from_primary do
    count = Inquiry.count
  end
end
~~~

## Note

`active_record_replica` is a very simple layer that inserts itself into the call chain whenever a replica is configured.
By observation we noticed that all reads are made to a select set of methods and
all writes are made directly to one method: `execute`.

Using this observation `active_record_replica` only needs to intercept calls to the known select apis:
* select_all
* select_one
* select_rows
* select_value
* select_values

Calls to the above methods are redirected to the replica active record model `ActiveRecordReplica::Replica`.
This model is 100% managed by the regular Active Record mechanisms such as connection pools etc.

This lightweight approach ensures that all calls to the above API's are redirected to the replica without impacting:
* Transactions
* Writes
* Any SQL calls directly to `execute`

One of the limitations with this approach is that any code that performs a query by calling `execute` direct will not
be redirected to the replica instance. In this case replace the use of `execute` with one of the the above select methods.


## Note when using `dependent: destroy`

When performing in-memory only model assignments Active Record will create a transaction against the primary even though
the transaction may never be used.

Even though the transaction is unused it sends the following messages to the primary database:
~~~sql
SET autocommit=0
commit
SET autocommit=1
~~~

This will impact the primary database if sufficient calls are made, such as in batch workers.

For Example:

~~~ruby
class Parent < ActiveRecord::Base
  has_one :child, dependent: :destroy
end

class Child < ActiveRecord::Base
  belongs_to :parent
end

# The following code will create an unused transaction against the primary, even when reads are going to replicas:
parent = Parent.new
parent.child = Child.new
~~~

If the `dependent: :destroy` is removed it no longer creates a transaction, but it also means dependents are not
destroyed when a parent is destroyed.

For this scenario when we are 100% confident no writes are being performed the following can be performed to
ignore any attempt Active Record makes at creating the transaction:

~~~ruby
ActiveRecordReplica.skip_transactions do
  parent = Parent.new
  parent.child = Child.new
end
~~~

To help identify any code within a block that is creating transactions, wrap the code with
`ActiveRecordReplica.block_transactions` to make it raise an exception anytime a transaction is attempted:

~~~ruby
ActiveRecordReplica.block_transactions do
  parent = Parent.new
  parent.child = Child.new
end
~~~

## Rails 6 and above

Rails 6 natively supports multiple databases. It unfortunately only supports connection switching, so it cannot
transparently redirect reads to a replica database the way Active Record Replica does.

### Installation

Add to `Gemfile`

~~~ruby
gem "active_record_replica"
~~~

### Configuration

Move the existing database config into a section under `primary` and add another section called `primary_reader`
with `replica: true` to `database.yml`, for example:

~~~yaml
config: &config
  database: production
  username: username
  password: password
  encoding: utf8
  adapter:  mysql
  pool:     50

production:
  primary:
    <<: *config
    host: primary1
  primary_reader:
    <<: *config
    host: replica1
    replica: true
~~~

In order to tell Active Record about these entries, add the required entry to `ApplicationRecord`.
For example:

~~~ruby
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: {writing: :primary, reading: :primary_reader}
end
~~~

Rails recommends that all user models should inherit from ApplicationRecord, but if your models still inherit
directly from `ActiveRecord::Base` then the following code could be used:

~~~ruby
# Not recommended
class ActiveRecord::Base
  connects_to database: {writing: :primary, reading: :primary_reader}
end
~~~

## Rails 4 & 5

### Installation

Add to `Gemfile`

~~~ruby
gem "active_record_replica"
~~~

### Configuration

To enable replica reads for any environment just add a _replica:_ entry to database.yml
along with all the usual ActiveRecord database configuration options.

For Example:

~~~yaml
config: &config
  database: production
  username: username
  password: password
  encoding: utf8
  adapter:  mysql
  pool:     50

production:
  <<: *config
  host:     primary1
  replica:
    <<: *config
    host:   replica1
~~~

Sometimes it is useful to turn on replica reads per host, for example to activate
replica reads only on the linux host 'batch':

~~~yaml
config: &config
  database: production
  username: username
  password: password
  encoding: utf8
  adapter:  mysql
  pool:     50

production:
  <<: *config
  host:     primary1
<% if `hostname`.strip == 'batch' %>
  replica:
    <<: *config
    host:     replica1
<% end %>
~~~

If there are multiple replicas, it is possible to randomly select a replica on startup
to balance the load across the replicas:

~~~yaml
config: &config
  database: production
  username: username
  password: password
  encoding: utf8
  adapter:  mysql
  pool:     50

production:
  <<: *config
  host:     primary1
  replica:
    <<: *config
    host: <%= %w(replica1 replica2 replica3).sample %>
~~~

Replicas can also be assigned to specific hosts by using the hostname:

~~~yaml
config: &config
  database: production
  username: username
  password: password
  encoding: utf8
  adapter:  mysql
  pool:     50

production:
  <<: *config
  host:     primary1
  replica:
    <<: *config
    host:   <%= `hostname`.strip == 'app1' ? 'replica1' : 'replica2' %>
~~~

## Set primary as default for Read

The default behavior can also set to read/write operations against primary database.

Create an initializer file config/initializer/active_record_replica.rb to force read from primary:

~~~ruby
ActiveRecordReplica.read_from_primary!
~~~

Then use this method and supply block to read from the replica database:

~~~ruby
ActiveRecordReplica.read_from_replica do
  User.count
end
~~~

## Dependencies

See [.travis.yml](https://github.com/reidmorrison/active_record_replica/blob/master/.travis.yml) for the list of tested Ruby platforms

## Versioning

This project uses [Semantic Versioning](http://semver.org/).

## Contributing

1. Fork repository in Github.

2. Checkout your forked repository:

~~~shell
git clone https://github.com/your_github_username/active_record_replica.git
cd active_record_replica
~~~

3. Create branch for your contribution:

~~~shell
git co -b your_new_branch_name
~~~

4. Make code changes.

5. Ensure tests pass.

6. Push to your fork origin.

~~~shell
git push origin
~~~

7. Submit PR from the branch on your fork in Github.

## Author

[Reid Morrison](https://github.com/reidmorrison) :: @reidmorrison
