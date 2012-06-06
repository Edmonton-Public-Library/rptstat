# copies most rescent files from eplapp for updating to git.
SERVER=eplapp.library.ualberta.ca
USER=sirsi
REMOTE=~/Unicorn/EPLwork/anisbet/
LOCAL=~/projects/rptstat/

get:
	scp ${USER}@${SERVER}:${REMOTE}rptstat.pl ${LOCAL}
put:
	scp ${LOCAL}rptstat.pl ${USER}@${SERVER}:${REMOTE}
