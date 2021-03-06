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
C_PREVCLEANHOLDS=previous.days.cleanhold.stats
ARGS= -x 

put: test
	scp ${LOCAL}${APP} ${USER}@${SERVER}:${REMOTE}
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
	scp ${LOCAL}${C_PREVCLEANHOLDS} ${USER}@${SERVER}:${CLEAN}
install: test
	scp ${LOCAL}${APP} ${USER}@${SERVER}:/s/sirsi/Unicorn/Bincustom/${APP}
	ssh ${USER}@${SERVER} ${APP} ${ARGS}
