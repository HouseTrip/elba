# Elba [![Build Status](https://travis-ci.org/HouseTrip/elba.png?branch=master)](https://travis-ci.org/HouseTrip/elba)

Command-line interface for Amazon's ELB

## Getting started

Elba relies on the excellent [Fog gem](http://fog.io/) to connect to Amazon's APIs.
Start by setting up your `~/.fog`:

    # ~/.fog
    :default:
      :aws_access_key_id:      ABCDEF....
      :aws_secret_access_key:  123456....

## Available Commands

    elba help               # prints this message
    elba list               # list available load balancers, pass option -i to list instances attached
    elba attach [INSTANCES] # attach INSTANCES to an ELB, pass option --to to specify which one
    elba detach [INSTANCES] # detach INSTANCES from their ELB

Adding or removing a server will prompt the user which load balancer they wish the server to be removed from.
Your AWS Access Key defines which environments you have access to and thus which load balancers will be listed and available.

## Examples

    $ elba list
    2 ELB found:
     * staging
     * production

    $ elba list -i
    2 ELB found:
     * staging
       - i-xxxxxxxx
       - i-yyyyyyyy
     * production
       - i-aaaaaaaa
       - i-bbbbbbbb
       - i-cccccccc

    $ elba attach i-xxxxxxxx --to staging
    i-xxxxxxxx successfully added to staging

    $ elba attach i-xxxxxxxx
    More than one ELB available, pick one in the list
    0 staging
    1 production
    Use: ["0", "1"] 0
    i-xxxxxxxx is already attached to staging

    $ elba detach i-xxxxxxxx
    i-xxxxxxxx successfully detached from staging

    $ elba detach i-xxxxxxxx
    i-xxxxxxxx isn't attached to any known ELB

