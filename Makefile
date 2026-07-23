MSG?=


f-git:
	git add .  \
	&& git commit -m "$(MSG)" \
	&& git push origin main

up:
	cd habit-tracker \
	&& make up
