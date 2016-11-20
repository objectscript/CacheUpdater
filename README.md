# GitHubUpdater
Sync GitHub repositories into InterSystems Cache.

Installation
-----------

1. Download the latest Release .xml file and import it into Caché (any namespace, further referred to as {Namespace}).

Usage
-----------

Call 

    w ##class(CacheUpdater.Task).Update("Owner", "Repository", "Branch", "Username", "Password", "Namespace")

to download and compile classes from the Github repo.

Where
<b>Owner</b> - The name of the repository owner.<br>
<b>Repository</b> - The name of the repository.<br>
<b>Branch</b> - The name of the commit/branch/tag. If skipped the repository’s default branch (usually master) would be used.<br>
<b>Username</b> - GitHub user, who has access to repository. Optional for public repositories.<br>
<b>Password</b> - GitHub password, corresponding to Username. Optional for public repositories.<br>
Note, that with Username, you can make up to 5,000 requests per hour.
For unauthenticated requests, the rate limit allows to make up to 60 requests per hour.
Unauthenticated requests are associated with an IP address.<br>
<b>Namespace</b> - Namespace, where to download and compile repository.<br>
For example in the repository: https://github.com/intersystems-ru/Cache-MDX2JSON<br>
Owner - intersystems-ru, Repository - Cache-MDX2JSON.<br> 

OR

create task for syncing  GitHub repository → Cache instance do the following:

1. Go to SMP → System Operation → Task Manager → New Task
2. Set <i>Name</i> as desired
3. Set <i>Namespace to run task in</i> to {Namespace}
4. Set <i>Task type</i> to GitHub Update
5. Set <i>GitHubURL</i> to a valid GitHub repository, eg: https://github.com/intersystems-ru/Cache-MDX2JSON
7. Set <i>Namespace</i> to a Namespace you want to download GitHub repository to
8. Optionally provide <i>Username</i>, <i>Password</i> (for private repos or very frequent updates).
9. Set up the <i>Branch</i> you need. Possible values are names of commit/branch/tag
8. Set other parameters as desired and finish creation of the task

After task runs at least once you will get <i>GitHubURL</i> repository contents in <i>Namespace</i>



Continuous Integration
-----------

If you want more functionality check out [CacheGitHubCI](https://github.com/intersystems-ru/CacheGitHubCI) project.
