#!/usr/bin/python
"""Python module for the Kickstand. This is just a thin layer over the python module. """

__author__ = "Stephen Lien Harrell <sharrell@purdue.edu>"

#Note: All references to CMDB were changed to Kickstand (Edited by Kurt Kroeger)

import perl

class Error(Exception):
  pass

class Kickstand(object):
  """Class for accessing methods in the Kickstand perl module."""

  def __init__(self):
    """Initialize perl and load Kickstand module."""
    inc = perl.get_ref('@INC')
    inc.append('/usr/site/rcac/scripts/Kickstand/')
    perl.require('Kickstand')
    self.cmdb_instance = perl.callm('new', 'Kickstand')

  def UpdateHost(self, hostname, field_dict):
    """This function updates host. See documentation in perl module for
    more info. The interface is the same.
    """
    field_hash = perl.get_ref('%@')
    for k,v in field_dict.iteritems():
      field_hash[k] = v
    rows_modified = self.cmdb_instance.UpdateHost(hostname, field_hash)

    return rows_modified

  def AddPBSFailedJobStart(self, mom_node, sister_node, datestamp, jobid):
    """This function logs failed job starts for PBS.  See documentation
    for more info.  The interface is the same.
    """
    return self.cmdb_instance.AddPBSFailedJobStart(mom_node, sister_node,
                                                   datestamp, jobid)
