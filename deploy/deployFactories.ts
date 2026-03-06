// SPDX-License-Identifier: GPL-3.0-only

import {
  deploySenseContractAsProxy,
  ContractType,
  ContractInfo,
  loadContractAddressFromAddressBook,
} from './senseUtils';
import { assert, Contract, ethers, ZeroAddress } from 'ethers';
import { utils } from 'zksync-ethers';
import { getWallet } from './utils';

export default async function deployFactories(
  rulesOwner: string,
  factoriesProxyOwner: string,
  DEPLOYING_MIGRATION: boolean
): Promise<void> {
  const metadataURI = '';

  const deployer = getWallet();
  console.log(`Deployer address: ${deployer.address}`);

  const nonce = await deployer.getNonce();

  // TODO: This is a super-dirty hack which doesn't work half of the time (or if you change anything in deployment script).
  // Probably the problem has something to do with libraries already deployed or something.
  // If it fails - restart the node or play with nonce + values.
  const contractDeployer = new Contract(
    utils.CONTRACT_DEPLOYER_ADDRESS,
    utils.CONTRACT_DEPLOYER.fragments,
    deployer
  );

  // Print all addresses from nonce 0 to nonce + 20
  for (let i = 0; i < 30; i++) {
    const address = await contractDeployer.getNewAddressCreate.staticCall(
      deployer.address,
      nonce + i
    );
    console.log(`Nonce ${i} address: ${address}`);
  }
  let predictedSenseFactoryAddress = await contractDeployer.getNewAddressCreate.staticCall(
    deployer.address,
    DEPLOYING_MIGRATION ? nonce + 15 : nonce + 18
  );

  const factories: ContractInfo[] = [
    // Factories
    {
      name: 'AccessControlFactory',
      contractName: DEPLOYING_MIGRATION ? 'MigrationAccessControlFactory' : 'AccessControlFactory',
      contractType: ContractType.Factory,
      constructorArguments: [loadContractAddressFromAddressBook('AccessControlLock')],
    },
    {
      name: 'AccountFactory',
      contractName: DEPLOYING_MIGRATION ? 'MigrationAccountFactory' : 'AccountFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('AccountBeacon'),
        loadContractAddressFromAddressBook('AccountLock'),
      ],
    },
    {
      name: 'AppFactory',
      contractName: DEPLOYING_MIGRATION ? 'MigrationAppFactory' : 'AppFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('AppBeacon'),
        loadContractAddressFromAddressBook('AppLock'),
      ],
    },
    {
      name: 'FeedFactory',
      contractName: DEPLOYING_MIGRATION ? 'MigrationFeedFactory' : 'FeedFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('FeedBeacon'),
        loadContractAddressFromAddressBook('FeedLock'),
        predictedSenseFactoryAddress,
      ],
    },
    {
      name: 'GraphFactory',
      contractName: DEPLOYING_MIGRATION ? 'MigrationGraphFactory' : 'GraphFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('GraphBeacon'),
        loadContractAddressFromAddressBook('GraphLock'),
        predictedSenseFactoryAddress,
      ],
    },
    {
      name: 'GroupFactory',
      contractName: 'GroupFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('GroupBeacon'),
        loadContractAddressFromAddressBook('GroupLock'),
        predictedSenseFactoryAddress,
      ],
    },
    {
      name: 'NamespaceFactory',
      contractName: DEPLOYING_MIGRATION ? 'MigrationNamespaceFactory' : 'NamespaceFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('NamespaceBeacon'),
        loadContractAddressFromAddressBook('NamespaceLock'),
        predictedSenseFactoryAddress,
      ],
    },
  ];

  const rules: ContractInfo[] = [
    // Prerequisite rules for SenseFactory
    {
      contractName: 'AccountBlockingRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
    },
    {
      contractName: 'GroupGatedFeedRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
    },
    {
      contractName: 'UsernameSimpleCharsetNamespaceRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
    },
    {
      contractName: 'BanMemberGroupRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
    },
    {
      contractName: 'AdditionRemovalPidGroupRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
    },
  ];

  const deployedContracts: Record<string, ContractInfo> = {};

  for (const factory of factories) {
    deployedContracts[factory.name ?? factory.contractName] = await deploySenseContractAsProxy(
      factory,
      factoriesProxyOwner
    );
  }

  if (!DEPLOYING_MIGRATION) {
    const initializerABI = [
      'function initialize(address owner, string memory metadataURI) external',
    ];
    const initializerInterface = new ethers.Interface(initializerABI);
    const initializeEncodedCall = initializerInterface.encodeFunctionData('initialize', [
      rulesOwner,
      metadataURI,
    ]);
    for (const rule of rules) {
      deployedContracts[rule.contractName] = await deploySenseContractAsProxy(
        rule,
        rulesOwner,
        initializeEncodedCall
      );
    }
  }

  // sense factory
  const senseFactory_artifactName = DEPLOYING_MIGRATION ? 'MigrationSenseFactory' : 'SenseFactory';
  const senseFactory_args = [
    {
      accessControlFactory: deployedContracts['AccessControlFactory'].address,
      accountFactory: deployedContracts['AccountFactory'].address,
      appFactory: deployedContracts['AppFactory'].address,
      groupFactory: deployedContracts['GroupFactory'].address,
      feedFactory: deployedContracts['FeedFactory'].address,
      graphFactory: deployedContracts['GraphFactory'].address,
      namespaceFactory: deployedContracts['NamespaceFactory'].address,
    },
    {
      accountBlockingRule: DEPLOYING_MIGRATION
        ? ZeroAddress
        : deployedContracts['AccountBlockingRule'].address,
      groupGatedFeedRule: DEPLOYING_MIGRATION
        ? ZeroAddress
        : deployedContracts['GroupGatedFeedRule'].address,
      usernameSimpleCharsetRule: DEPLOYING_MIGRATION
        ? ZeroAddress
        : deployedContracts['UsernameSimpleCharsetNamespaceRule'].address,
      banMemberGroupRule: DEPLOYING_MIGRATION
        ? ZeroAddress
        : deployedContracts['BanMemberGroupRule'].address,
      addRemovePidGroupRule: DEPLOYING_MIGRATION
        ? ZeroAddress
        : deployedContracts['AdditionRemovalPidGroupRule'].address,
    },
  ];

  const wasSenseFactoryDeployed = loadContractAddressFromAddressBook('SenseFactory') !== undefined;

  const senseFactoryInfo = await deploySenseContractAsProxy(
    {
      name: 'SenseFactory',
      contractName: senseFactory_artifactName,
      contractType: ContractType.Factory,
      constructorArguments: senseFactory_args,
    },
    factoriesProxyOwner
  );

  if (wasSenseFactoryDeployed == false) {
    console.log(
      `SenseFactory address: ${senseFactoryInfo.address} <<< ??? >>> ${predictedSenseFactoryAddress} Predicted SenseFactory address`
    );
    assert(
      senseFactoryInfo.address === predictedSenseFactoryAddress,
      'Predicted SenseFactory address doesnt match the actual deployed address',
      'VALUE_MISMATCH'
    );
  }
}
