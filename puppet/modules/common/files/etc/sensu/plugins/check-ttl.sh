#!/bin/bash
#
# DESCRIPTION:
#   This script verifies the cluster entered has a TTL of less than or equal to MAXTTL on its FEs and RR, email if it does not
#
# OUTPUT:
#   Plain text
#
# PLATFORMS:
#   Linux
#
# Usage
#   ./check-ttl.sh <cluster> <# of FEs>  (ex: ./check-ttl.sh brown 4)
#

#max allowed TTL
MAXTTL=600

#which cluster
CSTR=$1

#if this variable increases, script exits with 2 which makes sensu fire a critical alert
I=0

#check the RR ttl internally
RR=$CSTR.rcac.purdue.edu
RRTTL=`dig @ns.purdue.edu +noall +answer $RR | awk '{print $2}' | head -n 1`
if [ "$RRTTL" -gt $MAXTTL ]
    then
        echo "$RR has an internal TTL of greater than $MAXTTL"
        echo "critical"
        let I++
    else
        echo "$RR internal TTL is ok"
fi

#check the RR ttl externally
RRTTL=`dig @ns3.purdue.edu +noall +answer $RR | awk '{print $2}' | head -n 1`
if [ "$RRTTL" -gt $MAXTTL ]
    then
        echo "$RR has an external TTL of greater than $MAXTTL"
        echo "critical"
        let I++
    else
        echo "$RR external is TTL ok"
fi

#check the FEs ttl internally
Y=$2-1
for (( X=0; X<=Y; X++ )); do

    #which FE to check
    FE=$CSTR-fe0$X.rcac.purdue.edu

    FETTL=`dig @ns.purdue.edu +noall +answer $FE | awk '{print $2}' | head -n 1`
    if [ "$FETTL" -gt $MAXTTL ]
        then
            echo "$FE has an internal TTL of greather than $MAXTTL"
            echo "critical"
            let I++
        else
            echo "$FE internal TTL is ok"
    fi
done

#check the FEs ttl externally
for (( X=0; X<=$Y; X++ )); do

    #which FE to check
    FE=$CSTR-fe0$X.rcac.purdue.edu

    FETTL=`dig @ns3.purdue.edu +noall +answer $FE | awk '{print $2}' | head -n 1`
    if [ "$FETTL" -gt $MAXTTL ]
        then
            echo "$FE has an external TTL of greather than $MAXTTL"
            echo "critical"
            let I++
        else
            echo "$FE external TTL is ok"
    fi
done

if [ "$I" -gt 0 ]
    then
        exit 2
fi
