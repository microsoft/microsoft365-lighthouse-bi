section Microsoft365Lighthouse;

// Global variables

authorize_uri = "https://login.microsoftonline.com/organizations/oauth2/v2.0/authorize";
client_id = Text.FromBinary(Extension.Contents("client_id"));
graph_endpoint = "https://graph.microsoft.com";
logout_uri = "https://login.microsoftonline.com/logout.srf";
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
token_uri = "https://login.microsoftonline.com/organizations/oauth2/v2.0/token";
version = "0.0.1-alpha";

// Default variables

DEFAULT_BATCH_SIZE = 5;

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
        ]),
        optional batchSize as (type number meta [
            Documentation.FieldCaption = "Batch Size",
            Documentation.FieldDescription = "The size of the batch for requests that support batching",
            Documentation.SampleValues = {"5, 10, or 15"}
        ])
    ) 
    as table meta [
        Documentation.Name = Extension.LoadString("DataSourceLabel"),
        Documentation.LongDescription = Extension.LoadString("DataSourceLabel"),
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

ConditionalAccessPolicies = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let
        result = Request.GetData("conditionalAccessPolicy", isCount, schemaOnly, tenants, "v1.0", true, "/v1.0/identity/conditionalAccess/policies", query, schema, metadata)
    in 
        result;

Contracts = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let
        result = Request.GetData("contract", isCount, schemaOnly, tenants, "v1.0", true, "/v1.0/contracts", query, schema, metadata)
    in
        result;

CredentialUserRegistrationDetails = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
        result = Request.GetData("credentialUserRegistrationDetails", isCount, schemaOnly, tenants, "beta", true, "/beta/reports/credentialUserRegistrationDetails", query, schema, metadata)
    in
        result;

Devices = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
        result = Request.GetData("device", isCount, schemaOnly, tenants, "v1.0", true, "/v1.0/devices", query, schema, metadata)
    in
        result;

Domains = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
        result = Request.GetData("domain", isCount, schemaOnly, tenants, "v1.0", true, "/v1.0/domains", query, schema, metadata)
    in
        result;

LicenseDetails = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
        result = if(schemaOnly) then 
                Schema.GetKnownType(metadata{[Version = "v1.0"]}[Value], "licenseDetails", "tenantId = text, userId = text")
            else
                let
                    requests = Request.Build(tenants, "/v1.0/users?$select=id"),
                    response = Rest.Feed(requests, true),

                    renamed = Table.RenameColumns(response, {"id", "userId"}, MissingField.Ignore),
                    batchRequests = Table.AddColumn(renamed, "secMgmtInsightsRequest", each "/users/" & [userId] & "/licenseDetails"),
                    
                    batchResponse = Request.Batch(batchRequests, batchSize, false)
                in 
                   batchResponse
    in
        result;

IdentitySecurityDefaultsEnforcementPolicy = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let
        removedTopParameter = if (query <> null and Text.Contains(query, "top")) then null else query,
        result = Request.GetData("identitySecurityDefaultsEnforcementPolicy", isCount, schemaOnly, tenants, "v1.0", false, "/v1.0/policies/identitySecurityDefaultsEnforcementPolicy", removedTopParameter, schema, metadata)
    in 
        result;

MyContracts = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let
        // The list of tenants is ignored for this function because this should be invoked against the partner tenant.
        result = Request.GetData("contract", isCount, schemaOnly, {}, "v1.0", true, "/v1.0/contracts", query, schema, metadata)
    in
        result;

MyOrganization = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let
        // The list of tenants is ignored for this function because this should be invoked against the partner tenant.
        result = Request.GetData("organization", isCount, schemaOnly, {}, "v1.0", true, "/v1.0/organization", query, schema, metadata)
    in
        result;

SignIns = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let
        result = Request.GetData("signIn", isCount, schemaOnly, tenants, "beta", true, "/beta/auditLogs/signIns", query, schema, metadata)
    in 
        result;

SubscribedSkus = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let
        removedTopParameter = if (query <> null and Text.Contains(query, "top")) then null else query,
        result = Request.GetData("subscribedSku", isCount, schemaOnly, tenants, "v1.0", true, "/v1.0/subscribedSkus", removedTopParameter, schema, metadata)
    in
        result;

Users = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) => 
    let
        result = Request.GetData("user", isCount, schemaOnly, tenants, "beta", true, "/beta/users", query, schema, metadata)
    in 
        result;

// Device Management 

DetectedApps = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
         result = if(schemaOnly) then 
                Schema.GetKnownType(metadata{[Version = "beta"]}[Value], "detectedApp", "tenantId = text, deviceId = text")
            else
                let
                    requests = Request.Build(tenants, "/beta/deviceManagement/managedDevices?$select=id&$filter=(((deviceType eq 'desktop') or (deviceType eq 'windowsRT') or (deviceType eq 'winEmbedded') or (deviceType eq 'surfaceHub') or (deviceType eq 'desktop') or (deviceType eq 'windowsRT') or (deviceType eq 'winEmbedded') or (deviceType eq 'surfaceHub') or (deviceType eq 'windowsPhone') or (deviceType eq 'holoLens')))"),
                    response = Rest.Feed(requests, true),

                    renamed = Table.RenameColumns(response, {"id", "deviceId"}, MissingField.Ignore),
                    batchRequests = Table.AddColumn(renamed, "secMgmtInsightsRequest", each "/deviceManagement/managedDevices/" & [deviceId] & "/detectedApps"),
                    
                    batchResponse = Request.Batch(batchRequests, batchSize, true)
                in 
                   batchResponse
    in 
        result;

DetectedMalwareState = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
         result = if(schemaOnly) then 
                Schema.GetKnownType(metadata{[Version = "beta"]}[Value], "windowsDeviceMalwareState", "tenantId = text, deviceId = text")
            else
                let
                    requests = Request.Build(tenants, "/beta/deviceManagement/managedDevices?$select=id&$filter=(((deviceType eq 'desktop') or (deviceType eq 'windowsRT') or (deviceType eq 'winEmbedded') or (deviceType eq 'surfaceHub') or (deviceType eq 'desktop') or (deviceType eq 'windowsRT') or (deviceType eq 'winEmbedded') or (deviceType eq 'surfaceHub') or (deviceType eq 'windowsPhone') or (deviceType eq 'holoLens')))"),
                    response = Rest.Feed(requests, true),

                    renamed = Table.RenameColumns(response, {"id", "deviceId"}, MissingField.Ignore),
                    batchRequests = Table.AddColumn(renamed, "secMgmtInsightsRequest", each "/deviceManagement/managedDevices/" & [deviceId] & "/windowsProtectionState/detectedMalwareState"),
                    
                    batchResponse = Request.Batch(batchRequests, batchSize, true)
                in 
                   batchResponse
    in 
        result;

DeviceCompliancePolicies = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
        result = Request.GetData("deviceCompliancePolicy", isCount, schemaOnly, tenants, "beta", true, "/beta/deviceManagement/deviceCompliancePolicies?$select=id,displayName,createdDateTime,description,lastModifiedDateTime,roleScopeTagIds,version", query, schema, metadata)
    in
        result;

DeviceCompliancePolicyStates = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
         result = if(schemaOnly) then 
                Schema.GetKnownType(metadata{[Version = "beta"]}[Value], "deviceCompliancePolicyState", "tenantId = text, deviceId = text")
            else
                let
                    requests = Request.Build(tenants, "/beta/deviceManagement/managedDevices?$select=id"),
                    response = Rest.Feed(requests, true),

                    renamed = Table.RenameColumns(response, {"id", "deviceId"}, MissingField.Ignore),
                    batchRequests = Table.AddColumn(renamed, "secMgmtInsightsRequest", each "/deviceManagement/managedDevices/" & [deviceId] & "/deviceCompliancePolicyStates"),
                    
                    batchResponse = Request.Batch(batchRequests, batchSize, true)
                in 
                   batchResponse
    in 
        result;

DeviceConfigurationProfiles = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
        result = Request.GetData("deviceConfiguration", isCount, schemaOnly, tenants, "beta", true, "/beta/deviceManagement/deviceConfigurations?$select=id,displayName,createdDateTime,description,lastModifiedDateTime,roleScopeTagIds,supportsScopeTags,deviceManagementApplicabilityRuleOsEdition,deviceManagementApplicabilityRuleOsVersion,deviceManagementApplicabilityRuleDeviceMode,version", query, schema, metadata)
    in
        result;

DeviceConfigurationStates = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
         result = if(schemaOnly) then 
                Schema.GetKnownType(metadata{[Version = "beta"]}[Value], "deviceConfigurationState", "tenantId = text, deviceId = text")
            else
                let
                    requests = Request.Build(tenants, "/beta/deviceManagement/managedDevices?$select=id"),
                    response = Rest.Feed(requests, true),

                    renamed = Table.RenameColumns(response, {"id", "deviceId"}, MissingField.Ignore),
                    batchRequests = Table.AddColumn(renamed, "secMgmtInsightsRequest", each "/deviceManagement/managedDevices/" & [deviceId] & "/deviceConfigurationStates"),
                    
                    batchResponse = Request.Batch(batchRequests, batchSize, true)
                in 
                   batchResponse
    in 
        result;

ManagedDevices = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
        result = Request.GetData("managedDevice", isCount, schemaOnly, tenants, "beta", true, "/beta/deviceManagement/managedDevices", query, schema, metadata)
    in
        result;

RemoteActionAudits = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
        result = Request.GetData("remoteActionAudit", isCount, schemaOnly, tenants, "beta", true, "/beta/deviceManagement/remoteActionAudits", query, schema, metadata)
    in 
        result;

SecurityBaselineStates = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
         result = if(schemaOnly) then 
                Schema.GetKnownType(metadata{[Version = "beta"]}[Value], "securityBaselineState", "tenantId = text, deviceId = text")
            else
                let
                    requests = Request.Build(tenants, "/beta/deviceManagement/managedDevices?$select=id"),
                    response = Rest.Feed(requests, true),

                    renamed = Table.RenameColumns(response, {"id", "deviceId"}, MissingField.Ignore),
                    batchRequests = Table.AddColumn(renamed, "secMgmtInsightsRequest", each "/deviceManagement/managedDevices/" & [deviceId] & "/securityBaselineStates"),
                    
                    batchResponse = Request.Batch(batchRequests, batchSize, true)
                in 
                   batchResponse
    in 
        result;

SubscriptionState = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
        result = Request.GetData("deviceManagementSubscriptionState", isCount, schemaOnly, tenants, "beta", false, "/beta/deviceManagement/subscriptionState", query, schema, metadata)
    in
        result;

UserExperienceAnalyticsDevicePerformance = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
        result = Request.GetData("userExperienceAnalyticsDevicePerformance", isCount, schemaOnly, tenants, "beta", true, "/beta/deviceManagement/userExperienceAnalyticsDevicePerformance", query, schema, metadata)
    in
        result;

UserExperienceAnalyticsDeviceStartupProcessPerformance = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
        result = Request.GetData("userExperienceAnalyticsDeviceStartupProcessPerformance", isCount, schemaOnly, tenants, "beta", true, "/beta/deviceManagement/userExperienceAnalyticsDeviceStartupProcessPerformance", query, schema, metadata)
    in
        result;

WindowsProtectionState = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
         result = if(schemaOnly) then 
                Schema.GetKnownType(metadata{[Version = "beta"]}[Value], "windowsProtectionState", "tenantId = text, deviceId = text")
            else
                let
                    requests = Request.Build(tenants, "/beta/deviceManagement/managedDevices?$select=id&$filter=(((deviceType eq 'desktop') or (deviceType eq 'windowsRT') or (deviceType eq 'winEmbedded') or (deviceType eq 'surfaceHub') or (deviceType eq 'desktop') or (deviceType eq 'windowsRT') or (deviceType eq 'winEmbedded') or (deviceType eq 'surfaceHub') or (deviceType eq 'windowsPhone') or (deviceType eq 'holoLens')))"),
                    response = Rest.Feed(requests, true),

                    renamed = Table.RenameColumns(response, {"id", "deviceId"}, MissingField.Ignore),
                    batchRequests = Table.AddColumn(renamed, "secMgmtInsightsRequest", each "/deviceManagement/managedDevices/" & [deviceId] & "/windowsProtectionState/"),
                    
                    batchResponse = Request.Batch(batchRequests, batchSize, true)
                in 
                   batchResponse
    in 
        result;

WindowsUpdateForBusinessConfigurationStates = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
         result = if(schemaOnly) then 
                Schema.GetKnownType(metadata{[Version = "beta"]}[Value], "windowsUpdateState", "tenantId = text, policyId = text")
            else
                let
                    requests = Request.Build(tenants, "/beta/deviceManagement/deviceConfigurations?$filter=isof(%27microsoft.graph.windowsUpdateForBusinessConfiguration%27)&$select=id"),
                    response = Rest.Feed(requests, true),

                    renamed = Table.RenameColumns(response, {"id", "policyId"}, MissingField.Ignore),
                    batchRequests = Table.AddColumn(renamed, "secMgmtInsightsRequest", each "/deviceManagement/deviceConfigurations/" & [policyId] & "/microsoft.graph.windowsUpdateForBusinessConfiguration/deviceUpdateStates"),
                    
                    batchResponse = Request.Batch(batchRequests, batchSize, true)
                in 
                   batchResponse
    in 
        result;

WindowsUpdateForBusinessConfigurations = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
        result = Request.GetData("windowsUpdateForBusinessConfiguration", isCount, schemaOnly, tenants, "beta", true, "/beta/deviceManagement/deviceConfigurations?$filter=isof(%27microsoft.graph.windowsUpdateForBusinessConfiguration%27)", query, schema, metadata)
    in
        result;

// Entities

EntityTable = #table({"Name", "Action", "Workload"}, {
    // Azure Active Directory 
    { "ConditionalAccessPolicies", ConditionalAccessPolicies , "AzureAd"},
    { "Contracts", Contracts, "AzureAd" },
    { "Domains", Domains, "AzureAd" },
    { "Devices", Devices, "AzureAd" },
    { "IdentitySecurityDefaultsEnforcementPolicy", IdentitySecurityDefaultsEnforcementPolicy, "AzureAd" },
    { "LicenseDetails", LicenseDetails, "AzureAd" },
    { "SignIns", SignIns, "AzureAd" },
    { "SubscribedSkus", SubscribedSkus, "AzureAd" },
    { "Users", Users, "AzureAd" },

    // Identity Protection
    { "RiskDetections", RiskDetections, "IdentityProtection" },

    // Intelligent Security Graph
    { "Alerts", Alerts, "IntelligentSecurity" },
    { "SecureScore", SecureScore, "IntelligentSecurity" },
    { "SecureScoreControlProfiles", SecureScoreControlProfiles, "IntelligentSecurity" }, 

    // Microsoft Endpoint Manager
    { "DetectedApps", DetectedApps, "EndpointManager" },
    { "DetectedMalwareState", DetectedMalwareState, "EndpointManager" },
    { "DeviceCompliancePolicies", DeviceCompliancePolicies, "EndpointManager" },
    { "DeviceCompliancePolicyStates", DeviceCompliancePolicyStates, "EndpointManager" },
    { "DeviceConfigurationProfiles", DeviceConfigurationProfiles, "EndpointManager" },
    { "DeviceConfigurationStates", DeviceConfigurationStates, "EndpointManager" },
    { "ManagedDevices", ManagedDevices, "EndpointManager" },
    { "RemoteActionAudits", RemoteActionAudits, "EndpointManager" },
    { "SecurityBaselineStates", SecurityBaselineStates, "EndpointManager" },
    { "SubscriptionState", SubscriptionState, "EndpointManager" },
    { "UserExperienceAnalyticsDevicePerformance", UserExperienceAnalyticsDevicePerformance, "EndpointManager" },
    { "UserExperienceAnalyticsDeviceStartupProcessPerformance", UserExperienceAnalyticsDeviceStartupProcessPerformance, "EndpointManager" },
    { "WindowsProtectionState", WindowsProtectionState, "EndpointManager" },
    { "WindowsUpdateForBusinessConfigurationStates", WindowsUpdateForBusinessConfigurationStates, "EndpointManager" },
    { "WindowsUpdateForBusinessConfigurations", WindowsUpdateForBusinessConfigurations, "EndpointManager" },

    // My
    { "MyContracts", MyContracts, "My" },
    { "MyOrganization", MyOrganization, "My" },

    // Reporting
    { "CredentialUserRegistrationDetails", CredentialUserRegistrationDetails, "Reporting" },
    { "MailboxUsageDetail", MailboxUsageDetail, "Reporting" },
    { "Office365ActivationsUserDetail", Office365ActivationsUserDetail, "Reporting" },
    { "Office365ActiveUserDetails", Office365ActiveUserDetails, "Reporting" },
    { "Office365ServicesUserCounts", Office365ServicesUserCounts, "Reporting" },
    { "OneDriveUsageAccountDetail", OneDriveUsageAccountDetail, "Reporting" },
    { "SharePointSiteUsageDetail", SharePointSiteUsageDetail, "Reporting" },
    { "TeamsUserActivityUserDetail", TeamsUserActivityUserDetail, "Reporting" },
    { "YammerActivityUserDetail", YammerActivityUserDetail, "Reporting" }
});

GetActionForEntity = (entity as text) =>
    try 
        EntityTable{[Entity = entity]}[Action]
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

// Helpers 

Request.Batch = (input as table, batchSize as number, isBetaRequest as logical) =>
    let 
        GetData = (tenantId as text, input as table) as table =>
            let
                data = Table.SelectColumns(input, {"id", "method", "secMgmtInsightsRequest"}),
                rename = Table.RenameColumns(data, {"secMgmtInsightsRequest", "url"}),

                contents = "{""requests"":" & Text.FromBinary(Json.FromValue(rename)) & "}",

                token = GetAccessToken(tenantId),
                urlToUse = if(isBetaRequest) then graph_endpoint & "/beta/$batch" else graph_endpoint & "/v1.0/$batch",

                response = Rest.Request(urlToUse, "application/json;odata.metadata=minimal;odata.streaming=false;IEEE754Compatible=false", token, Text.Remove(contents, "\")),
                document = Json.Document(response),

                expandedList = Table.FromList(document[responses], Splitter.SplitByNothing(), null, null, ExtraValues.Error), 
                expandedRecord = Table.ExpandRecordColumn(expandedList, "Column1", {"id", "status", "body"}),

                changedType = Table.TransformColumnTypes(expandedRecord, {{"id", type number}})
            in 
                changedType,

        Process = (tenantId as text, requests as table) => Table.GenerateByPage((previous) =>
            let
                indexValue = Value.Metadata(previous)[Index]?,
                index = if(indexValue <> null) then indexValue else 0,

                data = if(index = 0) then Table.FirstN(requests, batchSize) else 
                    let
                        initialValue = Table.Skip(requests, index), 
                        newValue = Table.FirstN(initialValue, batchSize)
                    in
                        if (Table.IsEmpty(newValue)) then null else newValue,

                output = if(data = null) then null else 
                    let 
                        addIndexColumn = Table.AddIndexColumn(data, "id", index + 1),
                        addMethodColumn = Table.AddColumn(addIndexColumn, "method", each "GET"),

                        response = GetData(tenantId, addMethodColumn),

                        joinedTable = Table.Join(addMethodColumn, "id", response, "id")
                    in
                        joinedTable
            in
                output meta [Index = index + batchSize]),

        groupedRows = Table.Group(input, {"tenantId"}, {{"requests", each _}}),
        runRequest = Table.AddColumn(groupedRows, "responses", each Process([tenantId], [requests])),

        removeErrors = Table.RemoveRowsWithErrors(runRequest, {"responses"}),
        responses = Table.Combine(removeErrors[responses]),

        // Remove the columns that were used for processing the request. This is done to prevent
        // any issue with duplicate columns names when expanding the response from the API.
        removed = Table.RemoveColumns(responses, {"id", "method", "secMgmtInsightsRequest", "status", "url"}, MissingField.Ignore),

        expandedBody = Table.ExpandRecordColumn(removed, "body", {"value"}),
        expandedValue = Table.ExpandListColumn(expandedBody, "value"),
                        
        filteredRows = Table.SelectRows(expandedValue, each [value] <> null and [value] <> ""),
        listOfColumns =  List.Union(List.Transform(filteredRows[value], each Record.FieldNames(_))),
        expanded = Table.ExpandRecordColumn(filteredRows, "value", listOfColumns)
    in 
        expanded;

Request.Build = (tenants as list, relativeUrl as text, optional query as text) =>
    let 
        request = if(query = null or query = "") then 
            Uri.Combine(graph_endpoint, relativeUrl)
        else if(Text.Contains(relativeUrl, "?")) then 
            Uri.Combine(graph_endpoint, relativeUrl) & "&" & Text.AfterDelimiter(query, "?")
        else 
            Uri.Combine(graph_endpoint, relativeUrl) & "?" & query,

        data = #table({"tenantId", "secMgmtInsightsScope", "secMgmtInsightsRequest"}, {{tenants, "https://graph.microsoft.com/.default", request}}),
        expandedList = Table.ExpandListColumn(data, "tenantId")
    in 
        expandedList;

Request.GetData = (resource as text, isCount as logical, schemaOnly as logical, tenants as list, version as text, isPaged as logical, relativeUrl as text, optional query, optional schema as type, optional metadata, optional additionalSchema as text) =>
    let
        result = if(schemaOnly) then 
                Schema.GetKnownType(metadata{[Version = version]}[Value], resource, if(additionalSchema <> null) then additionalSchema else "tenantId = text")
            else 
                let
                    requests = Request.Build(tenants, relativeUrl, query),
                    data = if(isCount) then Rest.Scalar(requests) else Rest.Feed(requests, isPaged, schema)
                in 
                    data
    in 
        result;

// Identity Protection 

RiskDetections = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
        result = Request.GetData("riskDetection", isCount, schemaOnly, tenants, "beta", true, "/beta/identityProtection/riskDetections", query, schema, metadata)
    in 
        result;

// Intelligent Security Graph

Alerts = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
        result = Request.GetData("alert", isCount, schemaOnly, tenants, "v1.0", true, "/v1.0/security/alerts", query, schema, metadata)
    in 
        result;

SecureScore = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
        result = Request.GetData("secureScore", isCount, schemaOnly, tenants, "v1.0", true, "/v1.0/security/secureScores", query, schema, metadata)
    in 
        result;

SecureScoreControlProfiles = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
        result = Request.GetData("secureScoreControlProfile", isCount, schemaOnly, tenants, "v1.0", true, "/v1.0/security/secureScoreControlProfiles", query, schema, metadata)
    in
        result;

// Navigation 
        
[DataSource.Kind="Microsoft365Lighthouse", Publish="Microsoft365Lighthouse.Publish"]
shared Microsoft365Lighthouse.Contents =  Value.ReplaceType(NavigationTable, Microsoft365Lighthouse.Type);

NavigationTable = (friendlyName as text, optional tenants as list, optional batchSize as number) as table =>
    let
        GetMetadata = (version as text) =>
            let
                data = Web.Contents(Uri.Combine(graph_endpoint, version & "/$metadata")), 
                buffered = Binary.Buffer(data), 
                metadata = Xml.Tables(buffered){0}[DataServices]{0}[#"http://docs.oasis-open.org/odata/ns/edm"]{0}[Schema]
            in 
                metadata,

        GetNestedNavigationTable = (input as table) as table =>
            let
                // Add data as a calculated column
                withData = Table.AddColumn(input, "Data", each View([Name], metadata, listOfTenants), type table),
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
                Rest.GetPages(graph_endpoint & "/v1.0/contracts?$select=customerId", GetAccessToken())[customerId],

        metadata = #table({"Version", "Value"}, {
            { "beta", GetMetadata("beta") },
            { "v1.0", GetMetadata("v1.0") }
        }),

        sizeOfBatchRequests = if(batchSize <> null) then batchSize else DEFAULT_BATCH_SIZE,

        // Group the items in the entity table by workload because those will be the folders in our navigation table
        grouped = Table.Group(EntityTable, {"Workload"}, {{"Nested", each _, type table [Name=text, Action=text, Workload=text]}}),
        // Rename the workload column to entity because the data will be used to build the folder structure of the navigation table
        renamed = Table.RenameColumns(grouped, {{"Workload", "Entity"}}),
        // Add data as a calculated column
        withData = Table.AddColumn(renamed, "Data", each GetNestedNavigationTable([Nested]), type table),
        // Add the item name and kind as fixed text values
        withItemKind = Table.AddColumn(withData, "ItemKind", each "Folder", type text),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Folder", type text),
         // Indicate that the node should be expandable
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each false, type logical),
        // Generate the navigation table
        navTable = Table.ToNavigationTable(withIsLeaf, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

View = (entity as text, metadata as table, tenants as list, batchSize as number) as table =>
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
                    result = GetActionForEntity(entity)(tenants, batchSize, false, false, finalQueryString, finalSchema),
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
                        value = GetActionForEntity(entity)(tenants, batchSize, true, false, finalQueryString),
                        converted = Number.FromText(value)
                    in
                        converted,

            // OnTake - handles the Table.FirstN transform, limiting
            // the maximum number of rows returned in the result set.
            // The count value should be >= 0.
            OnTake = (count as number) =>
                let
                    value = if(count >= 1000) then 999 else count,
                    newState = state & [ Top = value ]
                in
                    @View(newState),

            // OnSkip - handles the Table.Skip transform.
            // The count value should be >= 0.
            OnSkip = (count as number) =>
                let
                    newState = state & [ Skip = count ]
                in
                    @View(newState),

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

            //
            // Helper functions
            //
            // Retrieves the cached schema. If this is the first call
            // to CalculateSchema, the table type is calculated based on
            // entity name that was passed into the function.
            CalculateSchema = (state) as type =>
                if (state[Schema]? = null) then
                    GetActionForEntity(entity)(tenants, batchSize, false, true, null, null, metadata)
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

Rest.Feed = (requests as table, isPaged as logical, optional schema as type) => 
    let
        GetData = (input as record) =>
            let
                requestContainsTopQuery = Text.Contains(input[secMgmtInsightsRequest], "top="),

                data = try if(isPaged and not requestContainsTopQuery) then 
                        Rest.GetPages(input[secMgmtInsightsRequest], GetAccessToken(input[tenantId], input[secMgmtInsightsScope]), schema)
                    else
                        Rest.GetContents(input[secMgmtInsightsRequest], GetAccessToken(input[tenantId], input[secMgmtInsightsScope]), isPaged and requestContainsTopQuery, schema),

                // TODO - If the record has an error, then it should return an error and not null
                response = if(data[HasError] or Table.IsEmpty(data[Value])) then 
                        let
                            listOfFields = List.RemoveMatchingItems(Record.FieldNames(input), { "secMgmtInsightsRequest" }),
                            tableFromRecord = Table.FromRecords({input}, listOfFields),
                            value = Table.ToRecords(tableFromRecord)
                        in
                            value
                else 
                    let 
                        base = Table.AddColumn(data[Value], "secMgmtInsightsBase", each input),
                        listOfFields = List.RemoveMatchingItems(Record.FieldNames(input), { "secMgmtInsightsRequest" }),
                        expanded = Table.ExpandRecordColumn(base, "secMgmtInsightsBase", listOfFields), 
                        value = Table.ToRecords(expanded)
                    in
                        value
            in 
                response,

        data = Table.AddColumn(requests, "Column1", each GetData(_)),
        buffered = Table.Buffer(data), 

        mergedLists = List.Combine(buffered[Column1]),
        tableFromList = Table.FromList(mergedLists, Splitter.SplitByNothing(), {"Column1"}),
        
        listOfColumns =  List.Union(List.Transform(mergedLists, each Record.FieldNames(_))),
        expandedRecord = Table.ExpandRecordColumn(tableFromList, "Column1", listOfColumns)
    in 
        expandedRecord;

Rest.GetContents = (url as text, token as text, isPaged as logical, optional schema as type) =>
    let 
        response = Rest.Request(url, "application/json;odata.metadata=minimal;odata.streaming=false;IEEE754Compatible=false", token),
        body = Json.Document(response), 
        nextLink = Record.FieldOrDefault(body, "@odata.nextLink"),

        data = if (isPaged and schema = null) then 
                Diagnostics.LogFailure(
                    "Error converting response body. Are the records uniform?",
                    () => Table.FromRecords(body[value]))
            else if(isPaged and schema <> null) then 
                let
                    asTable = Table.FromList(body[value], Splitter.SplitByNothing(), {"Column1"}),
                    fields = Record.FieldNames(Type.RecordFields(Type.TableRow(schema))),
                    expanded = Table.ExpandRecordColumn(asTable, "Column1", fields),
                    // Remove the tenantId field if exists beacuse it is not found in each response 
                    // and other functions add base data and this value exist in that set.
                    removed = Table.RemoveColumns(expanded, {"tenantId"}, MissingField.Ignore)
                in
                    removed
            else
                let
                    abstract = if(Type.Is(Value.Type(body), List.Type)) then body else {body}, 
                    contents = Table.FromList(abstract, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                  
                    firstRow = contents{0}?,
                    listOfColumns =  List.Union(List.Transform(abstract, each Record.FieldNames(_))),

                    value = if(firstRow = null) then Table.FromRows({}) else Table.ExpandRecordColumn(contents, "Column1", listOfColumns)
                in
                    value
    in 
        data meta [NextLink = nextLink];

Rest.GetPages = (url as text, token as text, optional schema as type) => Table.GenerateByPage((previous) => 
    let
        // if previous is null, then this is our first page of data
        nextLink = if (previous = null) then url else Value.Metadata(previous)[NextLink]?,
        // if next link was set to null by the previous call, we know we have no more data
        page = if (nextLink <> null) then Rest.GetContents(nextLink, token, true, schema) else null
    in
        page);

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

        // TODO - Expression.Error: We cannot convert a value of type Binary to type Record.

        result = if(Record.HasFields(buffered, {"error"})) then 
                error Error.Record(buffered[error][code], buffered[error][message])
            else 
                buffered
    in 
        buffered;

Rest.Scalar = (requests as table) =>
    let
        GetData = (input as record) =>
            let 
                response = Rest.Request(input[secMgmtInsightsRequest], "text/plain", GetAccessToken(input[tenantId], input[secMgmtInsightsScope])),
                value = Text.FromBinary(response)
            in
                value,

        data = Table.AddColumn(requests, "Column1", each GetData(_)),
        output =  List.Sum(data[Column1])
    in 
        output;

// Reporting 

MailboxUsageDetail = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let 
        result = Request.GetData("mailboxUsageDetail", isCount, schemaOnly, tenants, "beta", true, "/beta/reports/getMailboxUsageDetail(period='D30')?$format=application/json", query, schema, metadata)
    in 
        result;

Office365ActivationsUserDetail = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let
        result = Request.GetData("office365ActivationsUserDetail", isCount, schemaOnly, tenants, "beta", true, "/beta/reports/getOffice365ActivationsUserDetail?$format=application/json", query, schema, metadata)
    in 
        result;

Office365ActiveUserDetails = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let
        result = Request.GetData("office365ActiveUserDetail", isCount, schemaOnly, tenants, "beta", true, "/beta/reports/getOffice365ActiveUserDetail(period='D30')?$format=application/json", query, schema, metadata)
    in 
        result;

Office365ServicesUserCounts = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let
        result = Request.GetData("office365ServicesUserCounts", isCount, schemaOnly, tenants, "beta", true, "/beta/reports/getOffice365ServicesUserCounts(period='D30')?$format=application/json", query, schema, metadata)
    in 
        result;

OneDriveUsageAccountDetail = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let
        result = Request.GetData("oneDriveUsageAccountDetail", isCount, schemaOnly, tenants, "beta", true, "/beta/reports/getOneDriveUsageAccountDetail(period='D30')?$format=application/json", query, schema, metadata)
    in 
        result;

SharePointSiteUsageDetail = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let
        result = Request.GetData("sharePointSiteUsageDetail", isCount, schemaOnly, tenants, "beta", true, "/beta/reports/getSharePointSiteUsageDetail(period='D30')?$format=application/json", query, schema, metadata)
    in 
        result;

TeamsUserActivityUserDetail = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let
        result = Request.GetData("teamsUserActivityUserDetail", isCount, schemaOnly, tenants, "beta", true, "/beta/reports/getTeamsUserActivityUserDetail(period='D30')?$format=application/json", query, schema, metadata)
    in 
        result;

YammerActivityUserDetail = (tenants as list, batchSize as number, isCount as logical, schemaOnly as logical, optional query as text, optional schema as type, optional metadata as table) =>
    let
        result = Request.GetData("yammerActivityUserDetail", isCount, schemaOnly, tenants, "beta", true, "/beta/reports/getYammerActivityUserDetail(period='D30')?$format=application/json", query, schema, metadata)
    in 
        result;