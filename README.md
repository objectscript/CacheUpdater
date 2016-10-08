# GitHubUpdater
Sync GitHub repositories into InterSystems Cache.

Installation
-----------

1. Download Task.cls.xml and import it into Caché (any namespace, further referred to as {Namespace}).

Usage
-----------

To create task for syncing  GitHub repository → Cache instance do the following:

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


Note that in order to sync CLS, MAC, INT, INC and DFI files they need to be stored<br>
at corresponding folders. For example: <br>
<b>for CLS</b>: cls/packagename/file.cls<br>
<b>for MAC</b>: mac/file.mac

Continuous Integration
-----------

If you want more functionality check out [CacheGitHubCI](https://github.com/intersystems-ru/CacheGitHubCI) project.
