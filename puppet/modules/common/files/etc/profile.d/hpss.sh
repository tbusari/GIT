# HPSS initialization script (sh)
PATH="$PATH:/opt/hpss/bin:/opt/hsi/bin"
export PATH
if [ -z "${MANPATH}" ]; then
        MANPATH=/usr/share/man:/usr/local/man:/opt/hpss/man
else
        MANPATH=${MANPATH}:/opt/hpss/man
fi
