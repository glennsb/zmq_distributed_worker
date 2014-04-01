# zmq distributed worker

A practice tool to play with [ZeroMQ](http://http://zeromq.org). It is used to queue work and run said work without having to do many many many qsub in our environment

# Requirements

 * Ruby 1.9
 * ZeroMQ

The various gems are listed in the Gemfile

# Usage

The basics are outlined below. One would also have to change the **oak.shells.ngs.omrf.in** hostname used for the logger host, as it is not yet a parameter.

## Start worker(s)

`bundle exec ruby -I . worker.rb 40`

Where 40 above is the number of jobs it is allowed to run at once

## Start logger/coordinator

`bundle exec ruby -I . logger.rb jobHost1 jobHost2 jobHostN`

Where jobHost1-N are the hostnames where the workers above are running

## Produce work

`bundle exec ruby -I . producer.rb JOBCLASS WORKING PATH PRIORITY JOBID`

# Adding Job Class

Types of jobs/analysis are defined via the two _Job.rb classes. Basically it wraps some bad shell commands
# License

MIT, see LICENSE.txt for full details
