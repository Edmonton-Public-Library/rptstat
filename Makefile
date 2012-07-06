# copies most rescent files from eplapp for updating to git.
SERVER=eplapp.library.ualberta.ca
USER=sirsi
REMOTE=~/Unicorn/EPLwork/anisbet/
LOCAL=~/projects/rptstat/
APP=rptstat.pl
C_WEEKDAYS=notice.stats
C_SVA=sva.stats
C_WEEKENDS=weekend.stats
C_SATURDAY=saturday.stats
C_SUNDAY=sunday.stats

put:
	perl -c ${LOCAL}${APP}
	scp ${LOCAL}${APP} ${USER}@${SERVER}:${REMOTE}
get:
	scp ${USER}@${SERVER}:${REMOTE}${APP} ${LOCAL}
test:
	perl -c ${LOCAL}${APP}
push_all_configs:
	scp ${LOCAL}${C_WEEKDAYS} ${USER}@${SERVER}:${REMOTE}
	scp ${LOCAL}${C_SVA} ${USER}@${SERVER}:${REMOTE}
	scp ${LOCAL}${C_WEEKENDS} ${USER}@${SERVER}:${REMOTE}
	scp ${LOCAL}${C_SATURDAY} ${USER}@${SERVER}:${REMOTE}
	scp ${LOCAL}${C_SUNDAY} ${USER}@${SERVER}:${REMOTE}
push_weekday_configs:
	scp ${LOCAL}${C_WEEKDAYS} ${USER}@${SERVER}:${REMOTE}
push_weekend_configs:
	scp ${LOCAL}${C_WEEKENDS} ${USER}@${SERVER}:${REMOTE}
