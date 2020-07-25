# first:
# open a browser and go to the IP address of this machine
# click OK

# next, on your local machine:
# ssh root@164.90.180.224

# on this machine:
dokku apps:create margo-api
dokku buildpacks:add margo-api https://github.com/fonsp/heroku-buildpack-julia

# on your local machine:
# git remote add dokku dokku@164.90.180.224:margo-api
# git push dokku

# you should see the Julia build process inside the same terminal