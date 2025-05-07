This repo contains all the files needed to deploy a containerized **Apache Git HTTP server** from scratch on a Linux host machine on GCP- using **Terraform** code via **GitHub Actions** workflow. As a one-time setup, the server downloads the AOSP mirror from *android.googlesource.com* and then serves Git requests for repo sync for AAOS builds.

## Steps to deploy Git server:

### 1. GCP Setup
Before we deploy the server via Actions workflow, we need a prerequisite setup on GCP.
#### 1a. Setup Workload Identity Federation (WIF) Pool and Provider
The Terraform workflow via GitHub Actions authenticates to your GCP project using WIF.
1. Go to *https://console.cloud.google.com/*
2. Go to *IAM & Admin* > *Workload Identity Pools* > Click on *Get Started*.
3. Create an identity pool (a group of similar auth methods):
    -   Enter Name as "github-for-aosp-mirror" and click on Continue.
4. Add OIDC Github Actions provider to pool (provider generates auth tokens which GCP will recognize):
    -   Select OpenID Connect (OIDC) as the provider within Select a provider.
    -   Set Provider name and Provider ID as "github-provider-for-aosp-mirror" under Provider details.
    -   Set the issuer to URL provided by GitHub (`https://token.actions.githubusercontent.com`) for GitHub Actions. Click  [here](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-google-cloud-platform#adding-a-google-cloud-workload-identity-provider)  for more information.
    -   Note down the Audience URL (shown just below Default audience) as below:
        -   example: `https://iam.googleapis.com/projects/<GCP_PROJECT_NUMBER>/locations/global/workloadIdentityPools/github/providers/github-provider-for-aosp-mirror`
    -   Click on Continue.
 5. Configure provider attributes:
     -   "google.subject" = "assertion.sub" and click on ADD MAPPING
     -   "attribute.actor" = "assertion.actor" and click on ADD MAPPING
     -   "attribute.aud" = "assertion.aud" and click on ADD MAPPING
     -   "attribute.repository" = "assertion.repository"
	 -   Click on ADD CONDITION under Attribute Conditions.
	 -   Configure Attribute Conditions as below
	     -   Condition CEL = `assertion.repository=='akshay-kaura/sdv-mirror-git-server'`
	 -   Click save.
5. Workload Identity Federation Pool and Provider has now been created successfully.
#### 1b. Create Service Account
This service account will be bind to the WIF provider we added earlier. Hence, when we use WIF in our Actions workflow, it will have only those permissions allowed under this service account.
1.  Under IAM & Admin, navigate to Service Accounts and click on Create service account.
2.  Provide  `github-sa-for-aosp-mirror`  as the name for the Service Account.
3.  Click on Create and continue.
4.  Under Grant this service account access to project, click on Select a role. In Filter, search for the following roles to the Service Account:
	-   `roles/compute.admin`
	-   `roles/iam.serviceAccountAdmin`
	-   `roles/resourcemanager.projectIamAdmin`
	-   `roles/storage.admin`
	-   `roles/secretmanager.admin`
	-   `roles/iam.workloadIdentityUser`
	-   `roles/iam.serviceAccountUser`
5.  Click on Continue and then Done. Your Service Account has now been created successfully.
#### 1c. Bind Service Account to the Workload Identity Provider
1.  To bind this Service Account to the Workload Identity Provider, Navigate to the Workload Identity Pool created earlier.
2.  Click on the name of the Workload Identity pool with Display Name as "github-for-aosp-mirror" from the list.
3.  Click on GRANT ACCESS and select  **Grant access using Service Account impersonation**.
4.  Select  `github-sa-for-aosp-mirror`  as the Service Account under Select service account.
5.  Select Attribute name as  `repository`  and attribute value as  `akshay-kaura/sdv-mirror-git-server`  (or your own repo name where Actions workflow will be executed) under Select principals (identities that can access the service account) and click on SAVE.
6.  In the next window, select Provider as  `github-provider-for-aosp-mirror`  from the drop-down menu and set OIDC ID token path as  `https://token.actions.githubusercontent.com`.
7.  Download the config file and and click on DISMISS.
8.  Confirm the Service account has been bound successfully under CONNECTED SERVICE ACCOUNTS tab.
#### 1d. Enable Secret Manager API
1. In the left-hand navigation menu, click on "APIs & Services" and then select "Library".
2. In the search bar at the top of the API Library page, type "Secret Manager API". Press Enter or click the search icon.
3. In the search results, click on the entry for "Secret Manager API". This will take you to the API's overview page.
4. On the Secret Manager API overview page, you should see an "Enable" button (likely in blue). Click this button.
5. Once the API is enabled, you will typically see the "Disable API" button on top.
#### 1e. Create `tfstate` Bucket
1. Navigate to the left-hand menu and click on "Cloud Storage" and then "Browser".
2. On the Cloud Storage Browser page, click the "+ Create bucket" button at the top.
3. In the "Name your bucket" field, enter the following name: `aosp-mirror-git-server-tfstate-<YOUR-PROJECT-ID>`. Replace `<PROJECT-ID>` with your actual Google Cloud Project ID.
4. Under "Choose where to store your data" select "Multi-region".
5. Under "Choose how to store your data", select "Set a default class > Standard".
6. Under "Choose how to control access to objects," select "Uniform" and enable "Enforce public access prevention on this bucket".
7. Under "Choose how to protect object data", keep default options but enable "Object versioning" toggle.
8. Under "Object versioning", Configure the following:
    -   Set "Max. number of versions per object" to `3`.
    -   Set "Expire noncurrent versions after" to `7`.
9. Review all your configurations and click the "Create" button at the bottom of the "Create a bucket" panel. 

### 2. GitHub Setup
We need to add repo secrets and variables on GitHub (considering they don't exist already).
#### 2a. Create Action Secrets
1. Go to the repo > Click on "Settings" > On left hand menu, under "Security", click on "Secrets and Variables" > Actions > Secrets
2. Add the following secrets (if not setup before):
	- `GIT_SERVER_PASSWORD`: The value can be anything but a strong password is recommended. This will be used to authenticate push events to the server.
	- `GH_REPO_PAT`: This is the Personal Access Token that can clone this (private) repo. The cloning of this repo onto host machine is one of the setup steps of our deployment workflow. You can create this PAT as follows
		- Click on your profile picture in the top right corner and select "Settings".
		- In your GitHub settings sidebar, scroll down and click on "Developer settings".
		- Create a Personal Access Token: In the Developer settings sidebar, click on "Personal access tokens" and then click on "Tokens (classic)". Then, click the "Generate new token (classic)" button.
		- Give Your Token a Name: In the "New personal access token" page, give your token a descriptive name (e.g., "Clone Private Repo Token").
		- Set an expiration date for your token. For security best practices, don't leave it set to "No expiration".
		- Under "Select scopes", ONLY check the box next to "repo". This single scope grants full access to private and public repositories. Since we only need it to clone this repo onto host, this is the minimum scope.
		- Scroll down and click the "Generate token" button.
		- GitHub will display your newly generated PAT. Copy this token immediately and store it in a safe place. You won't be able to see it again after you leave this page.
		- Finally, in the repo secrets, add this value for `GH_REPO_PAT`.
#### 2b. Create Action Variables
1. Under "Secrets and Variables" > Actions > Variables, add the following variables (if not setup before):
	- `GCP_BUCKET_NAME`: The value `aosp-mirror-git-server-tfstate-<YOUR-PROJECT-ID>`
	- `GCP_PROJECT_ID`: The value will be your GCP project ID.
	- `GCP_REGION`: The GCP region where you want to deploy.
	- `GCP_SA_EMAIL`: The service account email for `github-sa-for-aosp-mirror` that was bind to WIF provider.
	- `GCP_WIF_PROVIDER`: On the GCP Console, go to IAM & Admin, Workload Identity Federation, click on `github-for-aosp-mirror` provider pool.
		-   Once the pool details open, from the providers tab on the right of the page, click on edit icon.
		-   Scroll up and copy the URL mentioned under "Audiences" and paste only the part starting from  `projects/.../github-provider`
	    -   example:  `projects/<GCP_PROJECT_NUMBER>/locations/global/workloadIdentityPools/github/providers/github-provider-for-aosp-mirror`

### 3. Run GitHub Actions Workflow
1. Go to "Actions" tab in your repo. 
2. On left hand menu, click on workflow name: `Deploy AOSP Mirror Git Server to GCP`
3. On right hand side, click on "Run workflow" button > Select branch that you want to run (`sdv-public-aosp-mirror-git-server`) and click on "Run workflow" button.