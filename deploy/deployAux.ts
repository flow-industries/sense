// SPDX-License-Identifier: GPL-3.0-only

import {
  ContractType,
  loadAddressBook,
  saveContractToAddressBook,
  loadContractFromAddressBook,
  loadContractAddressFromAddressBook,
  deploySenseContractAsProxy,
} from './senseUtils';
import * as hre from 'hardhat';
import {
  getWallet,
  parseSenseContractDeployedEventsFromReceipt,
  getAddressFromEvents,
  verifyPrimitive,
} from './utils';
import { ethers, ZeroAddress } from 'ethers';

const metadataURI = '';

export const emptySourceStamp = {
  source: ZeroAddress,
  originalMsgSender: ZeroAddress,
  validator: ZeroAddress,
  nonce: 0,
  deadline: 0,
  signature: '0x',
};

export interface AppInitialProperties {
  graph: string;
  feeds: string[];
  namespace: string;
  groups: string[];
  defaultFeed: string;
  signers: string[];
  paymaster: string;
  treasury: string;
}

export async function deploySensePrimitives(primitivesOwner: string, DEPLOYING_MIGRATION: boolean) {
  const senseFactoryAddress = loadAddressBook()['SenseFactory'].address;
  if (!senseFactoryAddress) {
    throw new Error('SenseFactory not found in address book');
  }
  console.log(`Running script to interact with SenseFactory at ${senseFactoryAddress}`);

  // Load compiled contract info
  const senseFactoryArtifact = await hre.artifacts.readArtifact('SenseFactory');

  // Initialize contract instance for interaction
  const senseFactory = new ethers.Contract(
    senseFactoryAddress,
    senseFactoryArtifact.abi,
    getWallet() // Interact with the contract on behalf of this wallet
  );

  let account;
  let group = ZeroAddress;
  if (!DEPLOYING_MIGRATION) {
    account = await deploySenseAccount(senseFactory, primitivesOwner);
    group = await deploySenseGroup(senseFactory, primitivesOwner);
  }

  const feed = await deploySenseFeed(senseFactory, primitivesOwner);
  const graph = await deploySenseGraph(senseFactory, primitivesOwner);
  const namespace = await deploySenseNamespace(senseFactory, primitivesOwner);

  if (!DEPLOYING_MIGRATION) {
    const initialProperties: AppInitialProperties = {
      graph,
      feeds: [feed],
      namespace,
      groups: [group],
      defaultFeed: feed,
      signers: [],
      paymaster: getWallet().address,
      treasury: getWallet().address,
    };

    const app = await deploySenseApp(senseFactory, initialProperties, primitivesOwner);
  }
}

async function deploySenseAccount(
  senseFactory: ethers.Contract,
  primitivesOwner: string
): Promise<string> {
  const contractName = 'Account';
  const name = 'SenseExampleAccount';
  const existingContract = loadContractFromAddressBook(name);
  if (existingContract && existingContract.address) {
    console.log(`${contractName} already deployed at ${existingContract.address}. Skipping...`);
    return existingContract.address;
  }

  console.log('Deploying ' + name);
  const transaction = await senseFactory.deployAccount(
    metadataURI,
    primitivesOwner,
    [],
    [],
    emptySourceStamp,
    []
  );

  const txReceipt = (await transaction.wait()) as ethers.TransactionReceipt;
  const events = parseSenseContractDeployedEventsFromReceipt(txReceipt);
  const accountAddress = getAddressFromEvents(events, contractName);

  // await verifyPrimitive('Account', accountAddress, [
  //   getWallet().address,
  //   metadataURI,
  //   [],
  //   [],
  //   emptySourceStamp,
  //   []
  // ]);

  saveContractToAddressBook({
    name: name,
    contractName: contractName,
    contractType: ContractType.Misc,
    address: accountAddress,
  });

  return accountAddress;
}

async function deploySenseFeed(
  senseFactory: ethers.Contract,
  primitivesOwner: string
): Promise<string> {
  const contractName = 'Feed';
  const name = 'SenseGlobal' + contractName;
  const existingContract = loadContractFromAddressBook(name);
  if (existingContract && existingContract.address) {
    console.log(`${name} already deployed at ${existingContract.address}. Skipping...`);
    return existingContract.address;
  }

  console.log('Deploying ' + name);
  const transaction = await senseFactory.deployFeed(metadataURI, primitivesOwner, [], [], []);

  const txReceipt = (await transaction.wait()) as ethers.TransactionReceipt;
  const events = parseSenseContractDeployedEventsFromReceipt(txReceipt);
  const primitiveAddress = getAddressFromEvents(events, contractName);
  // const accessControlAddress = getAddressFromEvents(events, 'access-control');

  // await verifyPrimitive(contractName, primitiveAddress, [metadataURI, accessControlAddress]);

  saveContractToAddressBook({
    name: name,
    contractName: contractName,
    contractType: ContractType.Primitive,
    address: primitiveAddress,
  });

  return primitiveAddress;
}

async function deploySenseGroup(
  senseFactory: ethers.Contract,
  primitivesOwner: string
): Promise<string> {
  const contractName = 'Group';
  const name = 'SenseGlobal' + contractName;
  const existingContract = loadContractFromAddressBook(name);
  if (existingContract && existingContract.address) {
    console.log(`${name} already deployed at ${existingContract.address}. Skipping...`);
    return existingContract.address;
  }

  console.log('Deploying ' + name);
  const transaction = await senseFactory.deployGroup(
    metadataURI,
    primitivesOwner,
    [],
    [],
    [],
    ZeroAddress,
    []
  );

  const txReceipt = (await transaction.wait()) as ethers.TransactionReceipt;
  const events = parseSenseContractDeployedEventsFromReceipt(txReceipt);
  const primitiveAddress = getAddressFromEvents(events, contractName);
  // const accessControlAddress = getAddressFromEvents(events, 'access-control');

  // await verifyPrimitive(contractName, primitiveAddress, [metadataURI, accessControlAddress]);

  saveContractToAddressBook({
    name: name,
    contractName: contractName,
    contractType: ContractType.Primitive,
    address: primitiveAddress,
  });

  return primitiveAddress;
}

async function deploySenseGraph(
  senseFactory: ethers.Contract,
  primitivesOwner: string
): Promise<string> {
  const contractName = 'Graph';
  const name = 'SenseGlobal' + contractName;
  const existingContract = loadContractFromAddressBook(name);
  if (existingContract && existingContract.address) {
    console.log(`${name} already deployed at ${existingContract.address}. Skipping...`);
    return existingContract.address;
  }

  console.log('Deploying ' + name);
  const transaction = await senseFactory.deployGraph(metadataURI, primitivesOwner, [], [], []);

  const txReceipt = (await transaction.wait()) as ethers.TransactionReceipt;
  const events = parseSenseContractDeployedEventsFromReceipt(txReceipt);
  const primitiveAddress = getAddressFromEvents(events, contractName);
  // const accessControlAddress = getAddressFromEvents(events, 'access-control');

  // await verifyPrimitive(contractName, primitiveAddress, [metadataURI, accessControlAddress]);

  saveContractToAddressBook({
    name: name,
    contractName: contractName,
    contractType: ContractType.Primitive,
    address: primitiveAddress,
  });

  return primitiveAddress;
}

export async function deploySenseNamespace(
  senseFactory: ethers.Contract,
  primitivesOwner: string
): Promise<string> {
  const contractName = 'Namespace';
  const name = 'SenseGlobal' + contractName;
  const existingContract = loadContractFromAddressBook(name);
  if (existingContract && existingContract.address) {
    console.log(`${name} already deployed at ${existingContract.address}. Skipping...`);
    return existingContract.address;
  }

  console.log('Deploying ' + name);
  const namespace = 'sense';
  const nftName = 'Sense Usernames';
  const nftSymbol = 'SU';

  const transaction = await senseFactory.deployNamespace(
    namespace,
    metadataURI,
    primitivesOwner,
    [],
    [],
    [],
    nftName,
    nftSymbol
  );

  const txReceipt = (await transaction.wait()) as ethers.TransactionReceipt;
  const events = parseSenseContractDeployedEventsFromReceipt(txReceipt);
  const primitiveAddress = getAddressFromEvents(events, contractName);
  // const accessControlAddress = getAddressFromEvents(events, 'access-control');
  // const senseUsernameTokenURIProviderAddress = getAddressFromEvents(
  //   events,
  //   'username-token-uri-provider'
  // );

  // await verifyPrimitive('Namespace', primitiveAddress, [
  //   namespace,
  //   metadataURI,
  //   accessControlAddress,
  //   nftName,
  //   nftSymbol,
  //   senseUsernameTokenURIProviderAddress,
  // ]);

  saveContractToAddressBook({
    name: name,
    contractName: contractName,
    contractType: ContractType.Primitive,
    address: primitiveAddress,
  });

  return primitiveAddress;
}

export async function deploySenseApp(
  senseFactory: ethers.Contract,
  initialProperties: AppInitialProperties,
  primitivesOwner: string
): Promise<string> {
  const contractName = 'App';
  const name = 'SenseGlobal' + contractName;
  const existingContract = loadContractFromAddressBook(name);
  if (existingContract && existingContract.address) {
    console.log(`${name} already deployed at ${existingContract.address}. Skipping...`);
    return existingContract.address;
  }

  console.log('Deploying ' + name);
  console.log('Using the following initial properties:');
  console.log(initialProperties);
  const transaction = await senseFactory.deployApp(
    metadataURI,
    false,
    primitivesOwner,
    [],
    initialProperties,
    []
  );

  const txReceipt = (await transaction.wait()) as ethers.TransactionReceipt;

  const events = parseSenseContractDeployedEventsFromReceipt(txReceipt);
  const primitiveAddress = getAddressFromEvents(events, contractName);
  // const accessControlAddress = getAddressFromEvents(events, 'access-control');

  // await verifyPrimitive('App', appAddress, [
  //   metadataURI,
  //   false,
  //   accessControlAddress,
  //   initialProperties,
  //   [],
  // ]);

  saveContractToAddressBook({
    name: name,
    contractName: contractName,
    contractType: ContractType.Primitive,
    address: primitiveAddress,
  });

  return primitiveAddress;
}

export async function deploySenseAccessControl(primitivesOwner: string) {
  const contractName = 'OwnerAdminOnlyAccessControl';
  const contractType = 'AccessControl';
  const existingContract = loadContractFromAddressBook(contractName);
  if (existingContract && existingContract.address) {
    console.log(`${contractName} already deployed at ${existingContract.address}. Skipping...`);
    return existingContract.address;
  }

  console.log('Deploying Access Control');

  const accessControlFactoryAddress = loadContractFromAddressBook('AccessControlFactory')?.address;
  if (!accessControlFactoryAddress) {
    throw new Error('AccessControlFactory not found in address book');
  }

  const accessControlFactoryArtifact = await hre.artifacts.readArtifact('AccessControlFactory');

  const accessControlFactory = new ethers.Contract(
    accessControlFactoryAddress,
    accessControlFactoryArtifact.abi,
    getWallet()
  );

  const transaction = await accessControlFactory.deployOwnerAdminOnlyAccessControl(
    primitivesOwner,
    []
  );

  const txReceipt = (await transaction.wait()) as ethers.TransactionReceipt;
  const events = parseSenseContractDeployedEventsFromReceipt(txReceipt);
  const accessControlAddress = getAddressFromEvents(events, contractType);

  const accessControlLock = loadContractAddressFromAddressBook('AccessControlLock');
  if (!accessControlLock) {
    throw new Error('AccessControlLock not found in address book');
  }

  await verifyPrimitive('OwnerAdminOnlyAccessControl', accessControlAddress, [
    primitivesOwner,
    accessControlLock,
  ]);

  saveContractToAddressBook({
    contractName: 'OwnerAdminOnlyAccessControl',
    contractType: ContractType.Aux,
    address: accessControlAddress,
  });

  return accessControlAddress;
}

export async function deploySenseActionHub(
  proxyOwner: string,
  treasuryAddress: string,
  treasuryFeeBps: number
): Promise<string> {
  const contractName = 'ActionHub';
  const existingContract = loadContractFromAddressBook(contractName);
  if (existingContract && existingContract.address) {
    console.log(`${contractName} already deployed at ${existingContract.address}. Skipping...`);
    return existingContract.address;
  }

  // deploy action hub
  console.log('Deploying Action Hub...');
  const actionHub_artifactName = 'ActionHub';
  const actionHub_args: any[] = [treasuryAddress, treasuryFeeBps];

  const actionHub = await deploySenseContractAsProxy(
    {
      contractName: actionHub_artifactName,
      contractType: ContractType.Aux,
      constructorArguments: actionHub_args,
    },
    proxyOwner
  );

  return actionHub.address!;
}
