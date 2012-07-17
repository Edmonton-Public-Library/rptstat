# copies most rescent files from eplapp for updating to git.
SERVER=eplapp.library.ualberta.ca
USER=sirsi
REMOTE=~/Unicorn/EPLwork/anisbet/
LOCAL=~/projects/rptstat/
CLEAN=~/Unicorn/EPLwork/anisbet/Clean/
APP=rptstat.pl
C_NOTICES=notice.stats
C_SVA=sva.stats
C_CLEANHOLDS=cleanhold.stats

put:
	perl -c ${LOCAL}${APP}
	scp ${LOCAL}${APP} ${USER}@${SERVER}:${REMOTE}
get:
	scp ${USER}@${SERVER}:${REMOTE}${APP} ${LOCAL}
test:
	perl -c ${LOCAL}${APP}
push_all_configs:
	scp ${LOCAL}${C_NOTICES} ${USER}@${SERVER}:${REMOTE}
	scp ${LOCAL}${C_SVA} ${USER}@${SERVER}:${REMOTE}
push_notice_configs:
	scp ${LOCAL}${C_NOTICES} ${USER}@${SERVER}:${REMOTE}
push_sva_configs:
	scp ${LOCAL}${C_SVA} ${USER}@${SERVER}:${REMOTE}
push_clean_configs:
	scp ${LOCAL}${C_CLEANHOLDS} ${USER}@${SERVER}:${CLEAN}
