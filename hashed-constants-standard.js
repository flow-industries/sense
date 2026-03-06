// SPDX-License-Identifier: GPL-3.0-only

//////////////////////////////////// Permissions ////////////////////////////////////

// Definition:
keccak256("sense.permission.{permissionName}");

// Examples:
keccak256("sense.permission.SkipPayments");
keccak256("sense.permission.ChangeRules");
keccak256("sense.permission.BanMembers");

//////////////////////////////////// Custom Params ////////////////////////////////////

// Definition:
keccak256("sense.param.{paramName}");

// Examples:
keccak256("sense.param.accessControl"); 
keccak256("sense.param.sourceStamp"); 

//////////////////////////////////// Extra data ////////////////////////////////////

// Definition:
keccak256("sense.data.{extraDataKey}"); 

// Examples:
keccak256("sense.data.groupFeed"); 
keccak256("sense.data.source");

//////////////////////////////////// Roles ////////////////////////////////////

// Definition:
keccak256("sense.role.{roleId}"); 

// Examples:
keccak256("sense.role.Owner"); 
keccak256("sense.role.Admin"); 

//////////////////////////////////// Storage ////////////////////////////////////

// Definition:
keccak256("sense.storage.{contractType}.{storedObject}");

// Examples:
keccak256("sense.storage.AccessControl.roles");

//////////////////////////////////// Contract Type ////////////////////////////////////

// Definition:
keccak256("sense.contract.{contractType}[.{subType}]"); 

// Examples:
keccak256("sense.contract.AccessControl.OwnerAdminOnlyAccessControl"); 
keccak256("sense.contract.AccessControl.RoleBasedAccessControl"); 
