section Microsoft365Lighthouse;

// Global variables

authorize_uri = "https://login.microsoftonline.com/organizations/oauth2/v2.0/authorize";
client_id = Text.FromBinary(Extension.Contents("client_id"));
logout_uri = "https://login.microsoftonline.com/logout.srf";
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
token_uri = "https://login.microsoftonline.com/organizations/oauth2/v2.0/token";

default_batch_size = 5;

msgraph_endpoint = "https://graph.microsoft.com/";
manageoffice_endpoint = "https://manage.office.com/";
partnercenter_endpoint = "https://api.partnercenter.microsoft.com/";

// Control variables

OperationType = [
    Count = 0,
    Request = 1,
    SchemaOnly = 2
];

// Data Source Kind description

Microsoft365Lighthouse = [
    Authentication = [
        OAuth = [
            FinishLogin = FinishLogin,
            Logout = Logout,
            Refresh = Refresh,
            StartLogin = StartLogin
        ]
    ], 
    TestConnection = (value) => { "Microsoft365Lighthouse.Contents" }
];

// Data Source UI publishing description

Microsoft365Lighthouse.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://github.com/microsoft/microsoft365-lighthouse-bi",
    SourceImage = Microsoft365Lighthouse.Icons,
    SourceTypeImage = Microsoft365Lighthouse.Icons
];

Microsoft365Lighthouse.Icons = [
    Icon16 = { Extension.Contents("Connector16.png"), Extension.Contents("Connector20.png"), Extension.Contents("Connector24.png"), Extension.Contents("Connector32.png") },
    Icon32 = { Extension.Contents("Connector32.png"), Extension.Contents("Connector40.png"), Extension.Contents("Connector48.png"), Extension.Contents("Connector64.png") }
];

Microsoft365Lighthouse.Type = type function (
        connectionName as (type text meta [
            Documentation.FieldCaption = "Connection Friendly Name",
            Documentation.FieldDescription = "A friendly name to identify your tenant",
            Documentation.SampleValues = {"Contoso - US, Contoso - EMEA, or Contoso APAC"}
        ]),
        optional tenants as (type list meta [
            Documentation.FieldCaption = "List of Tenants",
            Documentation.FieldDescription = "The list of tenants used by the functions",
            Documentation.SampleValues = {"14be956d-744d-4c76-9c22-e61e28d377e5, 2e5cb289-2986-4f15-bc8e-56d7157210f8"}
        ])
    ) 
    as table meta [
        Documentation.Name = Extension.LoadString("DataSourceLabel"),
        Documentation.LongDescription = Extension.LoadString("DataSourceDescription"),
        Documentation.Icon = Extension.Contents("Connector32.png")
    ];

// Authentication 

FinishLogin = (context, callbackUri, state) =>
    let
        parts = Uri.Parts(callbackUri)[Query],
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                    TokenMethod(token_uri, "authorization_code", "code", parts[code])
    in
        result;

GetAccessToken = (optional tenantId as text, optional scope as text) =>
    let 
        authResult = if (tenantId <> null) then 
            TokenMethod("https://login.microsoftonline.com/" & tenantId & "/oauth2/v2.0/token", "refresh_token", "refresh_token", Extension.CurrentCredential()[refresh_token], scope)
        else
            TokenMethod(token_uri, "refresh_token", "refresh_token", Extension.CurrentCredential()[refresh_token], scope)
    in 
        authResult[access_token];

Logout = (token) => logout_uri;

Refresh = (resourceUrl, refresh_token) => TokenMethod(token_uri, "refresh_token", "refresh_token", refresh_token);

StartLogin = (resourceUrl, state, display) =>
    let
        authorizeUrl = authorize_uri & "?" & Uri.BuildQueryString([
            client_id = client_id,  
            redirect_uri = redirect_uri,
            state = state,
            scope = "offline_access https://graph.microsoft.com/.default",
            response_type = "code",
            response_mode = "query",
            login = "login",
            acr_values = "urn:microsoft:policies:mfa"
        ])
    in
        [
            LoginUri = authorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = 860,
            WindowWidth = 1024,
            Context = null
        ];

TokenMethod = (tokenUri, grantType, tokenField, parameter, optional scope as text) =>
    let
        queryString = [
            client_id = client_id,
            scope = if (scope <> null) then scope else "offline_access https://graph.microsoft.com/.default",
            grant_type = grantType,
            redirect_uri = redirect_uri
        ],
        queryWithCode = Record.AddField(queryString, tokenField, parameter),

        tokenResponse = Web.Contents(tokenUri, [
            Content = Text.ToBinary(Uri.BuildQueryString(queryWithCode)),
            Headers = [
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json"
            ],
            ManualStatusHandling = {400, 401, 403} 
        ]),
        body = Json.Document(tokenResponse),
        result = if (Record.HasFields(body, {"error", "error_description"})) then 
                    error Error.Record(body[error], body[error_description], body)
                 else
                    body
    in 
        result;

// Azure Active Directory

/*
* Gets a table of conditional access policies for the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of conditional access policies for the speicified tenants.
*/
ConditionalAccessPolicies = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let
        request = Request.Build(tenants, msgraph_endpoint, "v1.0/identity/conditionalAccess/policies", {"Policy.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "v1.0", "conditionalAccessPolicy", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in 
        result;

/*
* Gets a table of credential user registration details fo the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of credential user registration details fo the specified list of tenants.
*/
CredentialUserRegistrationDetails = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let 
        request = Request.Build(tenants, msgraph_endpoint, "beta/reports/credentialUserRegistrationDetails", {"Reports.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "credentialUserRegistrationDetails", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in
        result;

/*
* Gets a table of devices for the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of devices for the specified list of tenants.
*/
Devices = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let 
        request = Request.Build(tenants, msgraph_endpoint, "v1.0/devices", {"Directory.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "v1.0", "device", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in
        result;

/*
* Gets a table of domains for the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of domains for the specified list of tenants.
*/
Domains = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let 
        request = Request.Build(tenants, msgraph_endpoint, "v1.0/domains", {"Directory.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "v1.0", "domain", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in
        result;

/*
* Gets a table of groups for the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of groups for the specified list of tenants.
*/
Groups = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let 
        request = Request.Build(tenants, msgraph_endpoint, "v1.0/groups", {"Directory.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "v1.0", "group", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in
        result;

/*
* Gets a table that reflects the state of Identity Security Defaults for the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table that reflects the state of Identity Security Defaults for the specified list of tenants.
*/
IdentitySecurityDefaultsEnforcementPolicy = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let
        removedTopParameter = Request.RemoveQueryParameter("$top", query),
        request = Request.Build(tenants, msgraph_endpoint, "v1.0/policies/identitySecurityDefaultsEnforcementPolicy", {"Policy.Read.All"}, removedTopParameter), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "v1.0", "identitySecurityDefaultsEnforcementPolicy", schema),
        result = Request.Execute(operation, request, false, requestSchema)
    in 
        result;

/*
* Gets a table of license details associated with the users for the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of license details associated with the users for the specified list of tenants.
*/
LicenseDetails = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let 
        // TODO - Need to add support for additional fields 'userId = text' needs to be appended to the schema for this request
        requestSchema = Request.BuildSchema(msgraph_endpoint & "v1.0", "licenseDetails", schema),

        request = Request.Build(tenants, msgraph_endpoint, "v1.0/users?$select=id", {"Directory.Read.All"}),
        users = Request.Execute(OperationType[Request], request),
        renamed = Table.RenameColumns(users, {"id", "userId"}, MissingField.Ignore),
        
        // Ensure the tenantId and userId values are not present in the select portion of query string.
        // Since the query string will be ablled to the batch request these values will not present in that dataset.
        newQuery = Request.UpdateQueryParameter("$select", {"tenantId", "userId"}, query),

        batchRequests = Request.BuildBatches(
            renamed, 
            "https://graph.microsoft.com/v1.0/$batch",
            {"Directory.Read.All"}, 
            each if([userId] = null) then 
                    null
                else 
                    Request.AppendQuery("/users/" & [userId] & "/licenseDetails", newQuery)),

        result = Request.Batch(batchRequests, operation, query, requestSchema, {"Directory.Read.All"})
    in
        result;

/*
* Gets a table of authentication activities for users in the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of authentication activities for users in the specified list of tenants.
*/
SignIns = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let
        request = Request.Build(tenants, msgraph_endpoint, "beta/auditLogs/signIns", {"AuditLog.Read.All", "Directory.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "signIn", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in 
        result;

/*
* Gets a table of subscribed SKUs for the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of subscribed SKUs for the specified list of tenants.
*/
SubscribedSkus = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let
        removedTopParameter = Request.RemoveQueryParameter("$top", query),

        request = Request.Build(tenants, msgraph_endpoint, "v1.0/subscribedSkus", {"Directory.Read.All"}, removedTopParameter), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "v1.0", "subscribedSku", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in
        result;

/*
* Gets a table of users for the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of users for the specified list of tenants.
*/
Users = (tenants as list, operation as number, optional query as text, optional schema as type) => 
    let
        request = Request.Build(tenants, msgraph_endpoint, "v1.0/users", {"Directory.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "v1.0", "user", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in 
        result;

// Entities

EntityTable = #table({"Workload", "Name", "Action"}, {
    // Azure Active Directory 
    { "AzureAd", "ConditionalAccessPolicies", ConditionalAccessPolicies},
    { "AzureAd", "Domains", Domains },
    { "AzureAd", "Devices", Devices },
    { "AzureAd", "Groups", Groups },
    { "AzureAd", "IdentitySecurityDefaultsEnforcementPolicy", IdentitySecurityDefaultsEnforcementPolicy },
    { "AzureAd", "SignIns", SignIns },
    { "AzureAd", "SubscribedSkus", SubscribedSkus },
    { "AzureAd", "Users", Users },

    // Intelligent Security Graph
    { "IntelligentSecurity", "Alerts", Alerts },
    { "IntelligentSecurity", "SecureScore", SecureScore },
    { "IntelligentSecurity", "SecureScoreControlProfiles", SecureScoreControlProfiles },

    // Microsoft Endpoint Manager
    // { "EndpointManager", "DetectedApps", DetectedApps },
    // { "EndpointManager", "DetectedMalwareState", DetectedMalwareState },
    { "EndpointManager", "DeviceCompliancePolicies", DeviceCompliancePolicies },
    // { "EndpointManager", "DeviceCompliancePolicyStates", DeviceCompliancePolicyStates },
    { "EndpointManager", "DeviceConfigurationProfiles", DeviceConfigurationProfiles },
    //{ "EndpointManager", "DeviceConfigurationStates", DeviceConfigurationStates },
    { "EndpointManager", "DeviceManagementAuditEvents", DeviceManagementAuditEvents },
    { "EndpointManager", "GroupPolicyConfigurations", GroupPolicyConfigurations },
    { "EndpointManager", "ManagedDevices", ManagedDevices },
    { "EndpointManager", "MobileAppConfigurations", MobileAppConfigurations },
    { "EndpointManager", "MobileApps", MobileApps },
    { "EndpointManager", "ManagedAppPolicies", ManagedAppPolicies },
    { "EndpointManager", "RemoteActionAudits", RemoteActionAudits },
    // { "EndpointManager", "SecurityBaselineStates", SecurityBaselineStates },
    { "EndpointManager", "SubscriptionState", SubscriptionState },
    { "EndpointManager", "UserExperienceAnalyticsDevicePerformance", UserExperienceAnalyticsDevicePerformance },
    { "EndpointManager", "UserExperienceAnalyticsDeviceStartupProcessPerformance", UserExperienceAnalyticsDeviceStartupProcessPerformance },
    // { "EndpointManager", "WindowsProtectionState", WindowsProtectionState },
    { "EndpointManager", "WindowsAutopilotDeviceIdentities", WindowsAutopilotDeviceIdentities },
    // { "EndpointManager", "WindowsUpdateForBusinessConfigurationStates", WindowsUpdateForBusinessConfigurationStates },
    { "EndpointManager", "WindowsUpdateForBusinessConfigurations", WindowsUpdateForBusinessConfigurations },

    // My 
    { "My", "MyCustomers", MyCustomers },
    { "My", "MyOrganization", MyOrganization },
    { "My", "MyResellers", MyResellers },

    // Office 365 Service Communications 
    { "ServiceCommunications", "ServiceCurrentStatus", ServiceCurrentStatus },
    { "ServiceCommunications", "ServiceHistoricalStatus", ServiceHistoricalStatus },
    { "ServiceCommunications", "ServiceMessages", ServiceMessages },

    // Reporting
    { "Reporting", "CredentialUserRegistrationDetails", CredentialUserRegistrationDetails },
    { "Reporting", "MailboxUsageDetails", MailboxUsageDetails },
    { "Reporting", "Office365ActivationsUserDetails", Office365ActivationsUserDetails },
    { "Reporting", "Office365ActiveUserDetails", Office365ActiveUserDetails },
    { "Reporting", "Office365ServicesUserCounts", Office365ServicesUserCounts },
    { "Reporting", "OneDriveUsageAccountDetails", OneDriveUsageAccountDetails },
    { "Reporting", "SharePointSiteUsageDetails", SharePointSiteUsageDetails },
    { "Reporting", "TeamsUserActivityUserDetails", TeamsUserActivityUserDetails },
    { "Reporting", "YammerActivityUserDetails", YammerActivityUserDetails }
});

/*
* Gets the action for the specified entity.
* 
* entity: Name of the action to perform.
*
* Returns a function that represnts the action to perform.
*/
GetActionForEntity = (entity as text) =>
    try 
        EntityTable{[Name = entity]}[Action]
     otherwise
         let
             message = Text.Format("Could not find entity: '#{0}'", {entity})
         in
             Diagnostics.Trace(TraceLevel.Error, message, () => error message, true);

// Extensions

Diagnostics = Extension.LoadFunction("Diagnostics.pqm");

Diagnostics.LogValue = Diagnostics[LogValue];
Diagnostics.LogFailure = Diagnostics[LogFailure];
Diagnostics.WrapHandlers = Diagnostics[WrapHandlers];

Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

Schema = Extension.LoadFunction("Schema.pqm");

Schema.GetKnownType = Schema[GetKnownType];

Table.ChangeType = Extension.LoadFunction("Table.ChangeType.pqm");
Table.GenerateByPage = Extension.LoadFunction("Table.GenerateByPage.pqm");
Table.ToNavigationTable = Extension.LoadFunction("Table.ToNavigationTable.pqm");

// Helper 

Value.IfNull = (a, b) => if a <> null then a else b;

// Intelligent Security Graph

/*
* Gets a table of security alerts for the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of security alerts for the specified list of tenants.
*/
Alerts = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let 
        request = Request.Build(tenants, msgraph_endpoint, "v1.0/security/alerts", {"SecurityEvents.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "v1.0", "alert", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in 
        result;

/*
* Gets a table of secure score entries for the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of secure score entries for the specified list of tenants.
*/
SecureScore = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let 
        request = Request.Build(tenants, msgraph_endpoint, "v1.0/security/secureScores", {"SecurityEvents.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "v1.0", "secureScore", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in 
        result;

/*
* Gets a table of secure score control profiles for the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of secure score control profiles for the specified list of tenants.
*/
SecureScoreControlProfiles = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let 
        request = Request.Build(tenants, msgraph_endpoint, "v1.0/security/secureScoreControlProfiles", {"SecurityEvents.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "v1.0", "secureScoreControlProfile", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in
        result;

// Microsoft Endpoint Manager

/*
* Gets a table of secure score control profiles for the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of secure score control profiles for the specified list of tenants.
*/
// DetectedApps = (tenants as list, operation as number, optional query as text, optional schema as type) =>
//     let 
//          result = if(schemaOnly) then 
//                 Schema.GetKnownType(metadata{[Version = "beta"]}[Value], "detectedApp", "tenantId = text, deviceId = text")
//             else
//                 let
//                     requests = Request.Build(tenants, "/beta/deviceManagement/managedDevices?$select=id&$filter=(((deviceType eq 'desktop') or (deviceType eq 'windowsRT') or (deviceType eq 'winEmbedded') or (deviceType eq 'surfaceHub') or (deviceType eq 'desktop') or (deviceType eq 'windowsRT') or (deviceType eq 'winEmbedded') or (deviceType eq 'surfaceHub') or (deviceType eq 'windowsPhone') or (deviceType eq 'holoLens')))"),
//                     response = Rest.Feed(requests, true, Request.GetScopeString({"DeviceManagementManagedDevices.Read.All"}, MSGRAPH_SCOPE_PREFIX), type table [tenantId = text, id = text]),
// 
//                     renamed = Table.RenameColumns(response, {"id", "deviceId"}, MissingField.Ignore),
//                     newQuery = Request.GetBatchQueryString(query, {"deviceId", "tenantId"}),
//                     
//                     batchRequests = Table.AddColumn(renamed, "secMgmtInsightsRequest", each if([deviceId] = null) then 
//                             null
//                         else 
//                             Request.AppendQuery("/deviceManagement/managedDevices/" & [deviceId] & "/detectedApps", newQuery)),
//                     
//                     batchResponse = Request.Batch(batchRequests, true, Request.GetScopeString({"DeviceManagementManagedDevices.Read.All"}, MSGRAPH_SCOPE_PREFIX), schema)
//                 in 
//                    batchResponse
//     in 
//         result;
// 
// DetectedMalwareState = (tenants as list, operation as number, optional query as text, optional schema as type) =>
//     let 
//          result = if(schemaOnly) then 
//                 Schema.GetKnownType(metadata{[Version = "beta"]}[Value], "windowsDeviceMalwareState", "tenantId = text, deviceId = text")
//             else
//                 let
//                     requests = Request.Build(tenants, "/beta/deviceManagement/managedDevices?$select=id&$filter=(((deviceType eq 'desktop') or (deviceType eq 'windowsRT') or (deviceType eq 'winEmbedded') or (deviceType eq 'surfaceHub') or (deviceType eq 'desktop') or (deviceType eq 'windowsRT') or (deviceType eq 'winEmbedded') or (deviceType eq 'surfaceHub') or (deviceType eq 'windowsPhone') or (deviceType eq 'holoLens')))"),
//                     response = Rest.Feed(requests, true, Request.GetScopeString({"DeviceManagementManagedDevices.Read.All"}, MSGRAPH_SCOPE_PREFIX), type table [tenantId = text, id = text]),
// 
//                     renamed = Table.RenameColumns(response, {"id", "deviceId"}, MissingField.Ignore),
//                     newQuery = Request.GetBatchQueryString(query, {"deviceId", "tenantId"}),
//                     
//                     batchRequests = Table.AddColumn(renamed, "secMgmtInsightsRequest", each if([deviceId] = null) then 
//                             null 
//                         else 
//                             Request.AppendQuery("/deviceManagement/managedDevices/" & [deviceId] & "/windowsProtectionState/detectedMalwareState", newQuery)),
//                     
//                     batchResponse = Request.Batch(batchRequests, true, Request.GetScopeString({"DeviceManagementManagedDevices.Read.All"}, MSGRAPH_SCOPE_PREFIX), schema)
//                 in 
//                    batchResponse
//     in 
//         result;

DeviceCompliancePolicies = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let 
        // TODO - Need to validate the select in the base query does not cause a query folding bug 
        request = Request.Build(tenants, msgraph_endpoint, "beta/deviceManagement/deviceCompliancePolicies?$select=id,displayName,createdDateTime,description,lastModifiedDateTime,roleScopeTagIds,version", {"DeviceManagementConfiguration.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "deviceCompliancePolicy", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in
        result;

// DeviceCompliancePolicyStates = (tenants as list, operation as number, optional query as text, optional schema as type) =>
//     let 
//          result = if(schemaOnly) then 
//                 Schema.GetKnownType(metadata{[Version = "beta"]}[Value], "deviceCompliancePolicyState", "tenantId = text, deviceId = text")
//             else
//                 let
//                     requests = Request.Build(tenants, "/beta/deviceManagement/managedDevices?$select=id"),
//                     response = Rest.Feed(requests, true, Request.GetScopeString({"DeviceManagementManagedDevices.Read.All"}, MSGRAPH_SCOPE_PREFIX), type table [tenantId = text, id = text]),
// 
//                     renamed = Table.RenameColumns(response, {"id", "deviceId"}, MissingField.Ignore),
//                     newQuery = Request.GetBatchQueryString(query, {"deviceId", "tenantId"}),
//                     
//                     batchRequests = Table.AddColumn(renamed, "secMgmtInsightsRequest", each if([deviceId] = null) then 
//                             null
//                         else
//                             Request.AppendQuery("/deviceManagement/managedDevices/" & [deviceId] & "/deviceCompliancePolicyStates", newQuery)),
//                     
//                     batchResponse = Request.Batch(batchRequests, true, Request.GetScopeString({"DeviceManagementConfiguration.Read.All"}, MSGRAPH_SCOPE_PREFIX), schema)
//                 in 
//                    batchResponse
//     in 
//         result;

DeviceConfigurationProfiles = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let 
        // TODO - Need to validate the select in the statement below does not cause a bug with query folding
        request = Request.Build(tenants, msgraph_endpoint, "beta/deviceManagement/deviceConfigurations?$select=id,displayName,createdDateTime,description,lastModifiedDateTime,roleScopeTagIds,supportsScopeTags,deviceManagementApplicabilityRuleOsEdition,deviceManagementApplicabilityRuleOsVersion,deviceManagementApplicabilityRuleDeviceMode,version", {"DeviceManagementConfiguration.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "deviceConfiguration", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in
        result;

// DeviceConfigurationStates = (tenants as list, operation as number, optional query as text, optional schema as type) =>
//     let 
//          result = if(schemaOnly) then 
//                 Schema.GetKnownType(metadata{[Version = "beta"]}[Value], "deviceConfigurationState", "tenantId = text, deviceId = text")
//             else
//                 let
//                     requests = Request.Build(tenants, "/beta/deviceManagement/managedDevices?$select=id"),
//                     response = Rest.Feed(requests, true, Request.GetScopeString({"DeviceManagementManagedDevices.Read.All"}, MSGRAPH_SCOPE_PREFIX), type table [tenantId = text, id = text]),
// 
//                     renamed = Table.RenameColumns(response, {"id", "deviceId"}, MissingField.Ignore),
//                     newQuery = Request.GetBatchQueryString(query, {"deviceId", "tenantId"}),
// 
//                     batchRequests = Table.AddColumn(renamed, "secMgmtInsightsRequest", each if([deviceId] = null) then 
//                             null
//                         else
//                             Request.AppendQuery("/deviceManagement/managedDevices/" & [deviceId] & "/deviceConfigurationStates", newQuery)),
//                     
//                     batchResponse = Request.Batch(batchRequests, true, Request.GetScopeString({"DeviceManagementConfiguration.Read.All"}, MSGRAPH_SCOPE_PREFIX), schema)
//                 in 
//                    batchResponse
//     in 
//         result;

DeviceManagementAuditEvents = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let 
        request = Request.Build(tenants, msgraph_endpoint, "beta/deviceManagement/auditEvents", {"DeviceManagementApps.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "auditEvent", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in
        result;

GroupPolicyConfigurations = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let 
        request = Request.Build(tenants, msgraph_endpoint, "beta/deviceManagement/groupPolicyConfigurations", {"DeviceManagementConfiguration.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "groupPolicyConfiguration", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in
        result;

ManagedAppPolicies = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let 
        request = Request.Build(tenants, msgraph_endpoint, "beta/deviceAppManagement/managedAppPolicies", {"DeviceManagementApps.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "managedAppPolicy", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in
        result;

ManagedDevices = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let 
        request = Request.Build(tenants, msgraph_endpoint, "beta/deviceManagement/managedDevices", {"DeviceManagementManagedDevices.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "managedDevice", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in
        result;

MobileAppConfigurations = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let 
        request = Request.Build(tenants, msgraph_endpoint, "beta/deviceAppManagement/mobileAppConfigurations", {"DeviceManagementApps.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "managedDeviceMobileAppConfiguration", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in 
        result;

MobileApps = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let 
        // TODO - Need to validate the select statement below does not cause a bug with query folding
        request = Request.Build(tenants, msgraph_endpoint, "beta/deviceAppManagement/mobileApps?$select=id,displayName,lastModifiedDateTime,roleScopeTagIds", {"DeviceManagementApps.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "mobileApp", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in 
        result;

RemoteActionAudits = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let 
        request = Request.Build(tenants, msgraph_endpoint, "beta/deviceManagement/remoteActionAudits", {"DeviceManagementManagedDevices.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "remoteActionAudit", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in 
        result;

// SecurityBaselineStates = (tenants as list, operation as number, optional query as text, optional schema as type) =>
//     let 
//          result = if(schemaOnly) then 
//                 Schema.GetKnownType(metadata{[Version = "beta"]}[Value], "securityBaselineState", "tenantId = text, deviceId = text")
//             else
//                 let
//                     requests = Request.Build(tenants, "/beta/deviceManagement/managedDevices?$select=id"),
//                     response = Rest.Feed(requests, true, Request.GetScopeString({"DeviceManagementManagedDevices.Read.All"}, MSGRAPH_SCOPE_PREFIX), type table [tenantId = text, id = text]),
// 
//                     renamed = Table.RenameColumns(response, {"id", "deviceId"}, MissingField.Ignore),
//                     newQuery = Request.GetBatchQueryString(query, {"deviceId", "tenantId"}),
// 
//                     batchRequests = Table.AddColumn(renamed, "secMgmtInsightsRequest", each if([deviceId] = null) then 
//                             null
//                         else 
//                             Request.AppendQuery("/deviceManagement/managedDevices/" & [deviceId] & "/securityBaselineStates", newQuery)),
//                     
//                     batchResponse = Request.Batch(batchRequests, true, Request.GetScopeString({"DeviceManagementConfiguration.Read.All"}, MSGRAPH_SCOPE_PREFIX), schema)
//                 in 
//                    batchResponse
//     in 
//         result;

SubscriptionState = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let 
        request = Request.Build(tenants, msgraph_endpoint, "beta/deviceManagement/subscriptionState", {"DeviceManagementManagedDevices.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "deviceManagementSubscriptionState", schema),
        result = Request.Execute(operation, request, false, requestSchema)
    in
        result;

UserExperienceAnalyticsDevicePerformance = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let 
        request = Request.Build(tenants, msgraph_endpoint, "beta/deviceManagement/userExperienceAnalyticsDevicePerformance", {"DeviceManagementManagedDevices.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "userExperienceAnalyticsDevicePerformance", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in
        result;

UserExperienceAnalyticsDeviceStartupProcessPerformance = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let 
        request = Request.Build(tenants, msgraph_endpoint, "beta/deviceManagement/userExperienceAnalyticsDeviceStartupProcessPerformance", {"DeviceManagementManagedDevices.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "userExperienceAnalyticsDeviceStartupProcessPerformance", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in
        result;

WindowsAutopilotDeviceIdentities = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let
        request = Request.Build(tenants, msgraph_endpoint, "beta/deviceManagement/windowsAutopilotDeviceIdentities", {"DeviceManagementServiceConfig.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "windowsAutopilotDeviceIdentity", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in 
        result;

// WindowsProtectionState = (tenants as list, operation as number, optional query as text, optional schema as type) =>
//     let 
//          result = if(schemaOnly) then 
//                 Schema.GetKnownType(metadata{[Version = "beta"]}[Value], "windowsProtectionState", "tenantId = text, deviceId = text")
//             else
//                 let
//                     requests = Request.Build(tenants, "/beta/deviceManagement/managedDevices?$select=id&$filter=(((deviceType eq 'desktop') or (deviceType eq 'windowsRT') or (deviceType eq 'winEmbedded') or (deviceType eq 'surfaceHub') or (deviceType eq 'desktop') or (deviceType eq 'windowsRT') or (deviceType eq 'winEmbedded') or (deviceType eq 'surfaceHub') or (deviceType eq 'windowsPhone') or (deviceType eq 'holoLens')))"),
//                     response = Rest.Feed(requests, true, Request.GetScopeString({"DeviceManagementManagedDevices.Read.All"}, MSGRAPH_SCOPE_PREFIX), type table [tenantId = text, id = text]),
// 
//                     renamed = Table.RenameColumns(response, {"id", "deviceId"}, MissingField.Ignore),
//                     newQuery = Request.GetBatchQueryString(query, {"deviceId", "tenantId"}),
// 
//                     batchRequests = Table.AddColumn(renamed, "secMgmtInsightsRequest", each if([deviceId] = null) then 
//                             null
//                         else 
//                             Request.AppendQuery("/deviceManagement/managedDevices/" & [deviceId] & "/windowsProtectionState", newQuery)),
//                     
//                     batchResponse = Request.Batch(batchRequests, true, Request.GetScopeString({"DeviceManagementManagedDevices.Read.All"}, MSGRAPH_SCOPE_PREFIX), schema)
//                 in 
//                    batchResponse
//     in 
//         result;

// WindowsUpdateForBusinessConfigurationStates = (tenants as list, operation as number, optional query as text, optional schema as type) =>
//     let 
//          result = if(schemaOnly) then 
//                 Schema.GetKnownType(metadata{[Version = "beta"]}[Value], "windowsUpdateState", "tenantId = text, policyId = text")
//             else
//                 let
//                     requests = Request.Build(tenants, "/beta/deviceManagement/deviceConfigurations?$filter=isof(%27microsoft.graph.windowsUpdateForBusinessConfiguration%27)&$select=id"),
//                     response = Rest.Feed(requests, true, Request.GetScopeString({"DeviceManagementConfiguration.Read.All"}, MSGRAPH_SCOPE_PREFIX), type table [tenantId = text, id = text]),
// 
//                     renamed = Table.RenameColumns(response, {"id", "policyId"}, MissingField.Ignore),
//                     newQuery = Request.GetBatchQueryString(query, {"policyId", "tenantId"}),
// 
//                     batchRequests = Table.AddColumn(renamed, "secMgmtInsightsRequest", each if([policyId] = null) then 
//                             null
//                         else 
//                             Request.AppendQuery("/deviceManagement/deviceConfigurations/" & [policyId] & "/microsoft.graph.windowsUpdateForBusinessConfiguration/deviceUpdateStates", newQuery)),
//                     
//                     batchResponse = Request.Batch(batchRequests, true, Request.GetScopeString({"DeviceManagementConfiguration.Read.All"}, MSGRAPH_SCOPE_PREFIX), schema)
//                 in 
//                    batchResponse
//     in 
//         result;

WindowsUpdateForBusinessConfigurations = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let 
        // TODO - Need to validate the filter statement below does not cause a bug with query folding
        request = Request.Build(tenants, msgraph_endpoint, "beta/deviceManagement/deviceConfigurations?$filter=isof(%27microsoft.graph.windowsUpdateForBusinessConfiguration%27)", {"DeviceManagementConfiguration.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "windowsUpdateForBusinessConfiguration", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in
        result;

// My

MyCustomers = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let
        // The list of tenants is ignored for this function because this should be invoked against the partner tenant.
        listOfTenants = Rest.GetPages(msgraph_endpoint & "/v1.0/organization?$select=id", GetAccessToken()),

        request = Request.Build(listOfTenants[id], msgraph_endpoint, "/v1.0/contracts", {"Directory.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "v1.0", "contract", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in
        result;

MyOrganization = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let
        // The list of tenants is ignored for this function because this should be invoked against the partner tenant.
        listOfTenants = Rest.GetPages(msgraph_endpoint & "/v1.0/organization?$select=id", GetAccessToken()),
        
        request = Request.Build(listOfTenants[id], msgraph_endpoint, "/v1.0/organization", {"Directory.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "v1.0", "organization", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in
        result;

MyResellers = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let
        // The list of tenants is ignored for this function because this should be invoked against the partner tenant.
        listOfTenants = Rest.GetPages(msgraph_endpoint & "/v1.0/organization?$select=id", GetAccessToken()),

        request = Request.Build(listOfTenants[id], partnercenter_endpoint, "/v1/relationships?relationship_type=IsIndirectCloudSolutionProviderOf", {"user_impersonation"}), 
        requestSchema = type table [],
        result = Request.Execute(operation, request, true, requestSchema)
    in
        result;

// Navigation 
        
[DataSource.Kind="Microsoft365Lighthouse", Publish="Microsoft365Lighthouse.Publish"]
shared Microsoft365Lighthouse.Contents =  Value.ReplaceType(NavigationTable, Microsoft365Lighthouse.Type);

NavigationTable = (friendlyName as text, optional tenants as list) as table =>
    let
        GetNestedNavigationTable = (input as table) as table =>
            let
                // Select the only column needed from the input for this function
                selected = Table.SelectColumns(input, {"Name"}),
                // Add data as a calculated column
                withData = Table.AddColumn(selected, "Data", each View([Name], listOfTenants), type table),
                // Add the item name and kind as fixed text values
                withItemKind = Table.AddColumn(withData, "ItemKind", each "Table", type text),
                withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table", type text),
                // Indicate that the node should not be expandable
                withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true, type logical),
                // Generate the nested navigation table
                navTable = Table.ToNavigationTable(withIsLeaf, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
            in 
                navTable,

        listOfTenants = if(tenants <> null and not List.IsEmpty(tenants)) then 
                tenants
            else 
                let 
                    contracts = Rest.GetPages(msgraph_endpoint & "/v1.0/contracts?$select=customerId", GetAccessToken()),
                    result = if (Table.HasColumns(contracts, {"customerId"})) then 
                            contracts[customerId]
                        else 
                           error Error.Record("No customers where discovered or specified", "Please verify that you used your partner credentials used to connect or specify a list of customer Azure Active Directory tenant identifiers.")
                in
                    result,

        // Group the items in the entity table by workload because those will be the folders in our navigation table
        grouped = Table.Group(EntityTable, {"Workload"}, {{"Nested", each _}}),
        // Convert the list of workloads to a table
        asTable = Table.FromList(grouped[Workload], Splitter.SplitByNothing()),
        // Rename the default column to key
        rename = Table.RenameColumns(asTable, {{"Column1", "Key"}}),
        // Add the name column as a calculated column 
        withName = Table.AddColumn(rename, "Name", each Extension.LoadString([Key])),
        // Add the data column as a calculated column
        withData = Table.AddColumn(withName, "Data", each GetNestedNavigationTable(grouped{[Workload=[Key]]}[Nested]), type table),
        // Add the item kind as a fixed text value
        withItemKind = Table.AddColumn(withData, "ItemKind", each "Feed", type text),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Feed", type text),
        // Indicate that the node should not be expandable
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each false, type logical),
        // Generate the navigation table
        navTable = Table.ToNavigationTable(withIsLeaf, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

View = (entity as text, tenants as list) as table =>
    let
        // Implementation of Table.View handlers.
        //
        // We wrap the record with Diagnostics.WrapHandlers() to get some automatic
        // tracing if a handler returns an error.
        //
        View = (state as record) => Table.View(null, Diagnostics.WrapHandlers([

            // Returns the table type returned by GetRows()
            GetType = () => CalculateSchema(state),

            // Called last - retrieves the data from the calculated URL
            GetRows = () => 
                let
                    finalSchema = CalculateSchema(state),
                    finalQueryString = CalculateQueryString(state),
                    result = GetActionForEntity(entity)(tenants, OperationType[Request], finalQueryString, finalSchema),
                    appliedType = Table.ChangeType(result, finalSchema)
                in
                    appliedType,

            // GetRowCount - called when all we want is the total row count.
            // Most OData services support $count, but it only works if
            // no other query parameters are sent (i.e. $top, or $filter).
            // Our implementation will first check for other query state -
            // if there are any state fields set by other handlers, we
            // return "..." unimplemented, because we won't be able to fold
            // the request to the server.
            GetRowCount = () as number =>
                if (Record.FieldCount(Record.RemoveFields(state, {"Url", "Entity", "Schema"}, MissingField.Ignore)) > 0) then
                    ...
                else
                    let
                        newState = state & [ RowCountOnly = true ],
                        finalQueryString = CalculateQueryString(newState),
                        value = GetActionForEntity(entity)(tenants, OperationType[CountyOnly], finalQueryString),
                        converted = Number.FromText(value)
                    in
                        converted,

            // OnSelectColumns - handles column selection
            OnSelectColumns = (columns as list) =>
                let
                    // get the current schema
                    currentSchema = CalculateSchema(state),
                    // get the columns from the current schema (which is an M Type value)
                    rowRecordType = Type.RecordFields(Type.TableRow(currentSchema)),
                    existingColumns = Record.FieldNames(rowRecordType),
                    // calculate the new schema
                    columnsToRemove = List.Difference(existingColumns, columns),
                    updatedColumns = Record.RemoveFields(rowRecordType, columnsToRemove),
                    newSchema = type table (Type.ForRecord(updatedColumns, false))
                in
                    @View(state & 
                        [ 
                            SelectColumns = columns,
                            Schema = newSchema
                        ]
                    ),

            // OnSkip - handles the Table.Skip transform.
            // The count value should be >= 0.
            OnSkip = (count as number) =>
                let
                    newState = state & [ Skip = count ]
                in
                    @View(newState),

            // OnSort - receives a list of records containing two fields: 
            //    [Name]  - the name of the column to sort on
            //    [Order] - equal to Order.Ascending or Order.Descending
            // If there are multiple records, the sort order must be maintained.
            //
            // OData allows you to sort on columns that do not appear in the result
            // set, so we do not have to validate that the sorted columns are in our 
            // existing schema.
            OnSort = (order as list) =>
                let
                    // This will convert the list of records to a list of text,
                    // where each entry is "<columnName> <asc|desc>"
                    sorting = List.Transform(order, (o) => 
                        let
                            column = o[Name],
                            order = o[Order],
                            orderText = if (order = Order.Ascending) then "asc" else "desc"
                        in
                            column & " " & orderText
                    ),
                    orderBy = Text.Combine(sorting, ", ")
                in
                    @View(state & [ OrderBy = orderBy ]),

            // OnTake - handles the Table.FirstN transform, limiting
            // the maximum number of rows returned in the result set.
            // The count value should be >= 0.
            OnTake = (count as number) =>
                let
                    value = if(count >= 1000) then 999 else count,
                    newState = state & [ Top = value ]
                in
                    @View(newState),

            //
            // Helper functions
            //
            // Retrieves the cached schema. If this is the first call
            // to CalculateSchema, the table type is calculated based on
            // entity name that was passed into the function.
            CalculateSchema = (state) as type =>
                if (state[Schema]? = null) then
                    GetActionForEntity(entity)(tenants, OperationType[SchemaOnly])
                else
                    state[Schema],

            // Calculates the final query string based on the current state.
            CalculateQueryString = (state) as text => 
                let
                    // Uri.BuildQueryString requires that all field values
                    // are text literals.
                    defaultQueryString = [],

                    // Check if we need to add the count query string parameter
                    qsWithRowCount =
                        if (state[RowCountOnly]? = true) then
                            defaultQueryString & [ #"$count" = true ]
                        else
                            defaultQueryString,

                    // Check for Top defined in our state
                    qsWithTop =
                        if (state[Top]? <> null) then
                            qsWithRowCount & [ #"$top" = Number.ToText(state[Top]) ]
                        else
                            qsWithRowCount,

                    // Check for Skip defined in our state
                    qsWithSkip = 
                        if (state[Skip]? <> null) then
                            qsWithTop & [ #"$skip" = Number.ToText(state[Skip]) ]
                        else
                            qsWithTop,

                    // Check for explicitly selected columns
                    qsWithSelect =
                        if (state[SelectColumns]? <> null) then
                            qsWithSkip & [ #"$select" = Text.Combine(List.RemoveItems(state[SelectColumns], {"tenantId"}), ",") ]
                        else
                            qsWithSkip,

                    qsWithOrderBy = 
                        if (state[OrderBy]? <> null) then
                            qsWithSelect & [ #"$orderby" = state[OrderBy] ]
                        else
                            qsWithSelect,

                    encodedQueryString = Uri.BuildQueryString(qsWithOrderBy)
                in
                    encodedQueryString
        ]))
    in
        View([Entity = entity]);

// Network

Rest.GetContents = (url as text, token as text, isPaged as logical, optional schema as type) =>
    let 
        response = Rest.Request(url, "application/json;odata.metadata=minimal;odata.streaming=false;IEEE754Compatible=false", token),
        document = Json.Document(response), 

        result = if(Record.HasFields(document, {"error"})) then 
                error Error.Record(document[error][code], document[error][message], document[error][innerError])
            else
                let
                    nextLink = Record.FieldOrDefault(document, "@odata.nextLink"),

                    data = if (isPaged and schema = null) then 
                            Diagnostics.LogFailure(
                                "Error converting response body. Are the records uniform?",
                                () => Table.FromRecords(document[value]))
                        else if(isPaged and schema <> null) then 
                            let
                                asTable = Table.FromList(document[value], Splitter.SplitByNothing(), {"Column1"}),
                                fields = Record.FieldNames(Type.RecordFields(Type.TableRow(schema))),
                                expanded = Table.ExpandRecordColumn(asTable, "Column1", fields),
                                // Remove the tenantId field if exists because it is not found in each response 
                                // and other functions add base data and this value exist in that set.
                                removed = Table.RemoveColumns(expanded, {"tenantId"}, MissingField.Ignore)
                            in
                                removed
                        else
                            let
                                abstract = if(Type.Is(Value.Type(document), List.Type)) then document else {document}, 
                                contents = Table.FromList(abstract, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                  
                                firstRow = contents{0}?,
                                listOfColumns =  List.Union(List.Transform(abstract, each Record.FieldNames(_))),

                                value = if(firstRow = null) then Table.FromRows({}) else Table.ExpandRecordColumn(contents, "Column1", listOfColumns)
                            in
                                value
                in 
                    data meta [NextLink = nextLink]
        in
            result;

Rest.GetPages = (url as text, token as text, optional schema as type) => 
    let
        response = Table.GenerateByPage((previous) => 
            let
                // if previous is null, then this is our first page of data
                nextLink = if (previous = null) then url else Value.Metadata(previous)[NextLink]?,
                // if next link was set to null by the previous call, we know we have no more data
                page = if (nextLink <> null) then Rest.GetContents(nextLink, token, true, schema) else null
            in
                page)
    in 
        response;

Rest.Request = (url as text, accept, token as text, optional content as text) => 
    let
       baseHeaders = [
            #"Accept" = accept,
            #"Accept-encoding" = "gzip, deflate",
            #"Authorization" = "Bearer " & token,
            #"User-Agent" = "microsoft365-lighthouse-bi" 
        ],        
        baseOptions = [
            ManualCredentials = true,
            ManualStatusHandling = {400, 401, 403}
        ],

        headers = if(content <> null) then Record.AddField(baseHeaders, "Content-Type", "application/json") else baseHeaders,
        options = if(content <> null) then Record.AddField(baseOptions, "Content", Text.ToBinary(content)) else baseOptions, 

        response = Web.Contents(url, Record.AddField(options, "Headers", headers)),
        buffered = Binary.Buffer(response),

        metadata = Value.Metadata(response),
        
        result = if(metadata[Response.Status] >= 400) then 
                let 
                    message = Text.Format(
                        "Request failed - status code: #{0} request-id: #{1}", 
                        {metadata[Response.Status], metadata[Headers][#"request-id"]})
                in
                    Diagnostics.Trace(TraceLevel.Error, message, () => buffered, true)
            else 
                buffered
    in 
        result;

Rest.Scalar = (requests as table) =>
    let
        GetData = (input as record) =>
            let 
                response = Rest.Request(input[secMgmtInsightsRequest], "text/plain", GetAccessToken(input[tenantId], input[scope])),
                value = Text.FromBinary(response)
            in
                value,

        data = Table.AddColumn(requests, "Column1", each GetData(_)),
        output =  List.Sum(data[Column1])
    in 
        output;

// Office 365 Service Communications

/*
* Gets a table of status details of Microsoft 365 services for the the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of status details of Microsoft 365 services for the the specified list of tenants.
*/
ServiceCurrentStatus = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let
        request = Request.Build(tenants, manageoffice_endpoint, "ServiceComms/CurrentStatus", {"ServiceHealth.Read"}, query, each manageoffice_endpoint & "api/v1.0/" & [tenantId] & "/ServiceComms/CurrentStatus"), 
        requestSchema = type table [tenantId = text, Id = text, Workload = text, StatusDate = datetime, WorkloadDisplayName = text, Status = text, IncidentIds = any, FeatureGroupStatusCollection = any],
        result = Request.Execute(operation, request, true, requestSchema)
    in
        result;

/*
* Gets a table of historical status details of Microsoft 365 services for the the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of historical status details of Microsoft 365 services for the the specified list of tenants.
*/
ServiceHistoricalStatus = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let
        request = Request.Build(tenants, manageoffice_endpoint, "ServiceComms/HistoricalStatus", {"ServiceHealth.Read"}, query, each manageoffice_endpoint & "api/v1.0/" & [tenantId] & "/ServiceComms/HistoricalStatus"), 
        requestSchema = type table [tenantId = text, Id = text, Workload = text, StatusDate = datetime, WorkloadDisplayName = text, Status = text, IncidentIds = any, FeatureGroupStatusCollection = any],
        result = Request.Execute(operation, request, true, requestSchema)
    in
        result;

/*
* Gets a table of status messages related to Microsoft 365 services for the the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of status messages related to Microsoft 365 services for the the specified list of tenants.
*/
ServiceMessages = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let
        request = Request.Build(tenants, manageoffice_endpoint, "ServiceComms/Messages", {"ServiceHealth.Read"}, query, each manageoffice_endpoint & "api/v1.0/" & [tenantId] & "/ServiceComms/Messages"), 
        requestSchema = type table [tenantId = text, Id = text, Name = text, Title = text, StartTime = datetimezone, EndTime = datetimezone, Status = text, Messages = any, LastUpdatedTime = datetimezone, Workload = text, WorkloadDisplayName = text, Feature = text, FeatureDisplayName = text],
        result = Request.Execute(operation, request, true, requestSchema)
    in
        result;

// Reporting 

/*
* Gets a table of mailbox usage details for the the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of mailbox usage details for the the specified list of tenants.
*/
MailboxUsageDetails = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let 
        request = Request.Build(tenants, msgraph_endpoint, "beta/reports/getMailboxUsageDetail(period='D30')?$format=application/json", {"Reports.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "mailboxUsageDetail", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in 
        result;

/*
* Gets a table of Office 365 activation user details for the the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of Office 365 activation user details for the the specified list of tenants.
*/
Office365ActivationsUserDetails = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let
        request = Request.Build(tenants, msgraph_endpoint, "beta/reports/getOffice365ActivationsUserDetail?$format=application/json", {"Reports.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "office365ActivationsUserDetail", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in 
        result;

/*
* Gets a table of Office 365 active user details for the the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of Office 365 active user details for the the specified list of tenants.
*/
Office365ActiveUserDetails = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let
        request = Request.Build(tenants, msgraph_endpoint, "beta/reports/getOffice365ActiveUserDetail(period='D30')?$format=application/json", {"Reports.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "office365ActiveUserDetail", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in 
        result;

/*
* Gets a table of Office 365 services user counts for the the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of Office 365 services user counts for the the specified list of tenants.
*/
Office365ServicesUserCounts = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let
        request = Request.Build(tenants, msgraph_endpoint, "beta/reports/getOffice365ServicesUserCounts(period='D30')?$format=application/json", {"Reports.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "office365ServicesUserCounts", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in 
        result;

/*
* Gets a table of OneDrive usage account details for the the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of OneDrive usage account details for the the specified list of tenants.
*/
OneDriveUsageAccountDetails = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let
        request = Request.Build(tenants, msgraph_endpoint, "beta/reports/getOneDriveUsageAccountDetail(period='D30')?$format=application/json", {"Reports.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "oneDriveUsageAccountDetail", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in 
        result;

/*
* Gets a table of SharePoint site usage details for the the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of SharePoint site usage details for the the specified list of tenants.
*/
SharePointSiteUsageDetails = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let
        request = Request.Build(tenants, msgraph_endpoint, "beta/reports/getSharePointSiteUsageDetail(period='D30')?$format=application/json", {"Reports.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "sharePointSiteUsageDetail", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in 
        result;

/*
* Gets a table of Teams user activity details for the the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of Teams user activity details for the the specified list of tenants.
*/
TeamsUserActivityUserDetails = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let
        request = Request.Build(tenants, msgraph_endpoint, "beta/reports/getTeamsUserActivityUserDetail(period='D30')?$format=application/json", {"Reports.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "teamsUserActivityUserDetail", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in 
        result;

/*
* Gets a table of Yammer user activity details for the the specified list of tenants.
*
* tenants: A list of tenants used when requesting data.
* operation: The type of request operation to perform. 
* query: An optional value that represents the query string to be used when requesting data.
* schema: An optional value that represents the schema of the resulting table.
*
* Returns a table of Yammer user activity details for the the specified list of tenants.
*/
YammerActivityUserDetails = (tenants as list, operation as number, optional query as text, optional schema as type) =>
    let
        request = Request.Build(tenants, msgraph_endpoint, "beta/reports/getYammerActivityUserDetail(period='D30')?$format=application/json", {"Reports.Read.All"}, query), 
        requestSchema = Request.BuildSchema(msgraph_endpoint & "beta", "yammerActivityUserDetail", schema),
        result = Request.Execute(operation, request, true, requestSchema)
    in 
        result;

// Requests

/*
* Appends the query string to the specified URL.
*
* url: The address of the resource being accessed.
* query: The query string to be appended to the specified URL.
* 
* Returns the URL with the query string appended.
*/
Request.AppendQuery = (url as text, optional query as text) =>
    let 
        result = if(query = null or query = "") then 
            url
        else if(Text.Contains(url, "?")) then 
            url & "&" & Text.AfterDelimiter(query, "?")
        else 
            url & "?" & query
    in 
        result;

Request.Batch = (requests as table) =>
    let
        source = ""
    in
        source;

/*
* Builds a table and populates with requests.
*
* tenants: List of tenants used to construct the table of requests.
* endpoint: The endpoint of the API to be used when contructing the requests.
* relativeUrl: The relative URL to be used when constructing the requests.
* scopes: A list of permissions that will be used when accessing the data.
* query: An optional value that represents the query string parameters to be used when contructing the requests.
* generator: An optional function used to generate the address for each request.
*
* Returns a table that has been populated with requests.
*/
Request.Build = (tenants as list, endpoint as text, relativeUrl as text, scopes as list, optional query as text, optional generator as function) => 
    let
        scope = Request.GetScopeString(scopes, endpoint),

        result = if(generator = null) then 
                let 
                    request = Request.AppendQuery(endpoint & relativeUrl, query),
                    data = #table({"tenantId", "request", "scope"}, {{tenants, request, scope}}),
                    expandedList = Table.ExpandListColumn(data, "tenantId")
                in
                    expandedList
            else
                let
                    base = #table({"tenantId", "scope"}, {{tenants, scope}}),
                    expandedList = Table.ExpandListColumn(base, "tenantId"), 
                    data = Table.AddColumn(expandedList, "request", generator)
                in
                    data
    in 
        result;

/*
* Builds a table thhat contains batch requests.
*
* input: 
* endpoint:
* scope:
* gennerator:
*
* Returns a table that contains batch requests.
*/
Request.BuildBatches = (input as table, endpoint as text, scopes as any, generator as function) =>
    let 
        base = Table.AddColumn(input, "request", generator),

        // Group the rows by the tenant identifier because each item in a request batch needs to be for the same tenant.
        grouped = Table.Group(base, {"tenantId"}, {{"requests", each _}}),

        batches = Table.AddColumn(grouped, "content", each Table.GenerateByPage((previous) =>
            let
                indexValue = Value.Metadata(previous)[Index]?,
                index = if(indexValue <> null) then indexValue else 0,

                data = if(index = 0) then Table.FirstN([requests], default_batch_size) else 
                    let
                        initialValue = Table.Skip([requests], index), 
                        newValue = Table.FirstN(initialValue, default_batch_size)
                    in
                        if (Table.IsEmpty(newValue)) then null else newValue,

                output = if(data = null) then null else 
                    let 
                        addIndexColumn = Table.AddIndexColumn(data, "id", index + 1),
                        addMethodColumn = Table.AddColumn(addIndexColumn, "method", each "GET")
                    in
                        Table.ToRecords(addMethodColumn)
            in
                output meta [Index = index + default_batch_size])),

        parts = Uri.Parts(endpoint),
        scopeValue = Request.GetScopeString(scopes, Text.Format("#{0}://#{1}/", {parts[Scheme], parts[Host]})),

        withRequest = Table.AddColumn(batches, "request", each endpoint),
        withScope = Table.AddColumn(withRequest, "scope", each scopeValue),
        
        // Remove the requests column that was added grouping the records. This column was only needed for this function.
        withoutRequests = Table.RemoveColumns(withScope, {"requests"}, MissingField.Ignore)
    in
        withoutRequests;

/*
* Builds the entry to request the schema if not known.
* 
* endpoint: The address where the metedata for the schema can be found.
* resource: Name of the resource type.
* schemaType: An optional value that represents the known schema.
*
* Returns a record use to obtain the schema if unknown; if known then the schema is returned.
*/
Request.BuildSchema = (endpoint as text, resource as text, optional schemaType as type) =>
    let
        value = if(schemaType <> null) then schemaType else [Endpoint = endpoint, Resource = resource]
    in 
        value;

/*
* Gets the OData metadata for the specified endpoint.
*
* endpoint: The base URL for where the metadata is located.
*
* Returns a table that contains the metadata for the specified endpoint.
*/
Request.GetMetadata = (endpoint as text) =>
    let
        data = Web.Contents(endpoint & "/$metadata"), 
        buffered = Binary.Buffer(data), 
        metadata = Xml.Tables(buffered){0}[DataServices]{0}[#"http://docs.oasis-open.org/odata/ns/edm"]{0}[Schema]
    in 
        metadata;

/*
* Gets the schema for the specified type.
*
* schema: An optional value that represent the response type.
*
* Returns the schema for the specified type..
*/
Request.GetSchema = (schema as any) =>
    let
        result = if(Type.Is(Value.Type(schema), Record.Type)) then 
                let 
                    metadata = Request.GetMetadata(schema[Endpoint]),
                    value = Schema.GetKnownType(metadata, schema[Resource], "tenantId = text")
                in 
                    value
            else 
                schema
    in
        result;

/*
* Gets the permission scope that will be used when requesting an access token.
*
* scopes: A list of scopes that should be included (e.g. Directory.Read.All).
* scopePrefix: The prefix for the specified scopes (e.g. https://graph.microsoft.com).
* 
* Returns the complete permission scope string (e.g. https://graph.microsoft.com/Directory.Read.All).
*/
Request.GetScopeString = (scopes as list, optional scopePrefix as text) as text =>
    let
        prefix = Value.IfNull(scopePrefix, ""),
        addPrefix = List.Transform(scopes, each prefix & _),
        asText = Text.Combine(addPrefix, " ")
    in
        asText;

/*
* Executes the specified request by perform the appropriate HTTP operation.
*
* operation: The type of operation to be performed. 
* requests: The table of requests to be performed.
* isResponsePaged: A flag indicating whether the response is paged or not.
* schema: An optional value that represent the response type.
*
* Returns the aggregated response for each HTTP operation performed.
*/
Request.Execute = (operation as number, requests as table, isResponsePaged as logical, optional schema as any) => 
    let
        GetData = (input as record) =>
            let
                requestContainsTopQuery = Text.Contains(input[request], "top="),

                data = try if(isResponsePaged and not requestContainsTopQuery) then 
                        Rest.GetPages(input[request], GetAccessToken(input[tenantId], input[scope]), schema)
                    else
                        Rest.GetContents(input[request], GetAccessToken(input[tenantId], input[scope]), isResponsePaged and requestContainsTopQuery, schema),

                response = if(data[HasError]) then 
                    let
                        fields = Record.FieldNames(Type.RecordFields(Type.TableRow(schema))),
                        asTable = Table.FromList(fields, Splitter.SplitByNothing()),

                        unpivot = Table.Unpivot(asTable, {"Column1"}, "Attribute", "Value"),
                        pivot = Table.Pivot(unpivot, List.Distinct(unpivot[Value]), "Value", "Attribute", each error data[Error]),

                        replace = Table.ReplaceErrorValues(pivot, {{"tenantId", input[tenantId]}}), 
                        value = Table.ToRecords(replace)
                    in 
                        value
                else if (Table.IsEmpty(data[Value])) then 
                        let
                            listOfFields = List.RemoveMatchingItems(Record.FieldNames(input), { "request", "scope" }),
                            tableFromRecord = Table.FromRecords({input}, listOfFields),
                            value = Table.ToRecords(tableFromRecord)
                        in
                            value
                else 
                    let 
                        base = Table.AddColumn(data[Value], "base", each input),
                        listOfFields = List.RemoveMatchingItems(Record.FieldNames(input), { "request", "scope" }),
                        expanded = Table.ExpandRecordColumn(base, "base", listOfFields), 
                        value = Table.ToRecords(expanded)
                    in
                        value
            in 
                response,

        result = if (operation = OperationType[Count]) then 
                Rest.Scalar(requests)
            else if(operation = OperationType[SchemaOnly]) then 
                Request.GetSchema(schema)
            else
                let 
                    data = Table.AddColumn(requests, "Column1", each GetData(_)),
                    buffered = Table.Buffer(data), 

                    mergedLists = List.Combine(buffered[Column1]),
                    tableFromList = Table.FromList(mergedLists, Splitter.SplitByNothing(), {"Column1"}),
        
                    listOfColumns =  List.Union(List.Transform(mergedLists, each Record.FieldNames(_))),
                    expandedRecord = Table.ExpandRecordColumn(tableFromList, "Column1", listOfColumns)
                in 
                    expandedRecord
    in 
        result;

/*
* Removes the specified parameter from the query string.
*
* field: Name of the parameter to be removed.
* query: The query string where the parameter should be removed.
* 
* Returns the modified query string or null if the passed query string was not specified.
*/
Request.RemoveQueryParameter = (field as text, optional query as text) =>
    let
        result = if(query = null) then 
                null
            else 
                let
                    parts = Uri.Parts("http://local.host" & Request.AppendQuery("/doesNotMatter", query)),
                    removed = Record.RemoveFields(parts[Query], {field}, MissingField.Ignore),
                    value = Uri.BuildQueryString(removed)
                in 
                    value
    in 
        result;

/*
* Updates the specified query string by removing the specified items.
*
* field: Name of the parameter to be updated.
* itemsToRemove: A list of items to be removed from the specified parameter.
* query: The query string where the parameter should be updated.
* 
* Returns the modified query string or null if the passed query string was not specified.
*/
Request.UpdateQueryParameter = (field as text, itemsToRemove as list, optional query as text) =>
    let
        result = if(query = null) then 
                null
            else
                let
                    parts = Uri.Parts("http://local.host" & Request.AppendQuery("/doesNotMatter", query)),

                    output = if(Record.HasFields(parts[Query], {field})) then
                            let
                                current = Text.Combine(List.RemoveItems(Text.Split(Record.Field(parts[Query], field), ","), itemsToRemove), ","),
                                removed = Record.RemoveFields(parts[Query], field, MissingField.Ignore),
                                added = Record.AddField(removed, field, current),

                                result = Uri.BuildQueryString(added)
                            in 
                                result
                        else
                            query
                in
                    output
    in
        result;