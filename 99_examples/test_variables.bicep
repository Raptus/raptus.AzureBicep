targetScope = 'subscription'

// Most simple test of variables, without deploying anything
// usage: az deployment sub create --location switzerlandnorth --name "test-variables" --template-file test_variables.bicep

output myTenantName string = tenant().displayName
