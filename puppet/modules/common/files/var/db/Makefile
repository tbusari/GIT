# Makefile to (re-)generate db versions of system database files.
# Copyright (C) 1996, 1997, 1998, 2011 Free Software Foundation, Inc.
# This file is part of the GNU C Library.
# Contributed by Ulrich Drepper <drepper@cygnus.com>, 1996.
#

# The GNU C Library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.

# The GNU C Library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.

# You should have received a copy of the GNU Lesser General Public
# License along with the GNU C Library; if not, see
# <http://www.gnu.org/licenses/>.

#DATABASES = $(wildcard /etc/passwd /etc/group /etc/ethers /etc/protocols \
#		       /etc/rpc /etc/services /etc/shadow /etc/gshadow \
#		       /etc/netgroup)

DATABASES = $(wildcard /etc/passwd /etc/group)

VAR_DB = /var/db

AWK = awk
MAKEDB = makedb --quiet

all: $(patsubst %,$(VAR_DB)/%.db,$(notdir $(DATABASES)))


$(VAR_DB)/passwd.db: passwd.sorted
	@echo -n "$(patsubst %.db,%,$(@F))... "
	@$(AWK) 'BEGIN { FS=":"; OFS=":" } \
		 /^[ \t]*$$/ { next } \
		 /^[ \t]*#/ { next } \
		 /^[^#]/ { printf ".%s ", $$1; print; \
			   printf "=%s ", $$3; print }' $^ | \
	$(MAKEDB) -o $@ -
	@echo "done."

$(VAR_DB)/group.db: group.sorted
	@echo -n "$(patsubst %.db,%,$(@F))... "
	@$(AWK) 'BEGIN { FS=":"; OFS=":" } \
		 /^[ \t]*$$/ { next } \
		 /^[ \t]*#/ { next } \
		 /^[^#]/ { printf ".%s ", $$1; print; \
			   printf "=%s ", $$3; print; \
			   if ($$4 != "") { \
			     split($$4, grmems, ","); \
			     for (memidx in grmems) { \
			       mem=grmems[memidx]; \
			       if (members[mem] == "") \
				 members[mem]=$$3; \
			       else \
				 members[mem]=members[mem] "," $$3; \
			     } \
			     delete grmems; } } \
		 END { for (mem in members) \
			 printf ":%s %s %s\n", mem, mem, members[mem]; }' $^ | \
	$(MAKEDB) -o $@ -
	@echo "done."
