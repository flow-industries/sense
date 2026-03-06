// SPDX-License-Identifier: GPL-3.0-only

import {
  ContractType,
  ContractInfo,
  loadContractAddressFromAddressBook,
  saveContractToAddressBook,
} from './senseUtils';
import { deployContract, getWallet } from './utils';
import * as hre from 'hardhat';
import { ethers, keccak256, toUtf8Bytes } from 'ethers';

async function deploy() {
  /////////////////// SETUP ///////////////////

  const preSalt = 'sense.contract.SenseFees';

  const implToDeploy: ContractInfo = {
    name: 'SenseFeesImpl',
    contractName: 'SenseFees',
    contractType: ContractType.Implementation,
    constructorArguments: [process.env.TREASURY_ADDRESS, process.env.TREASURY_FEE_BPS],
  };

  // const initializerABI = ['function initialize(address owner) external'];
  // const initializerInterface = new ethers.Interface(initializerABI);
  // const initializeEncodedCall = initializerInterface.encodeFunctionData('initialize', [
  //   '0x5FCD072a0BD58B6fa413031582E450FE724dba6D',
  // ]);

  const initializeEncodedCall = '0x';

  /////////////////////////////////////////////

  const proxyAdminPk = process.env.PROXY_ADMIN_PRIVATE_KEY;
  if (!proxyAdminPk) {
    throw new Error('PROXY_ADMIN_PRIVATE_KEY not found in environment variables');
  }

  const proxyAdminBalance = await getWallet(proxyAdminPk).getBalance();
  if (proxyAdminBalance < ethers.parseEther('0.01')) {
    throw new Error('Proxy admin balance is less than 0.01 ETH');
  }

  const proxyAdminAddress = await getWallet(proxyAdminPk).getAddress();

  console.log(`Using proxy admin private key with address: ${proxyAdminAddress}`);
  console.log(`Proxy admin balance: ${ethers.formatEther(proxyAdminBalance)}`);

  const senseCreate2OwnerPk = process.env.SENSE_CREATE2_OWNER_PRIVATE_KEY;
  if (!senseCreate2OwnerPk) {
    throw new Error('SENSE_CREATE2_OWNER_PRIVATE_KEY not found in environment variables');
  }

  const senseCreate2OwnerBalance = await getWallet(senseCreate2OwnerPk).getBalance();
  if (senseCreate2OwnerBalance < ethers.parseEther('0.01')) {
    throw new Error('SenseCreate2 Owner balance is less than 0.01 ETH');
  }

  console.log(
    `Using senseCreate2 owner private key with address: ${await getWallet(
      senseCreate2OwnerPk
    ).getAddress()}`
  );
  console.log(`SenseCreate2 owner balance: ${ethers.formatEther(senseCreate2OwnerBalance)}`);

  const senseCreate2OwnerWallet = getWallet(senseCreate2OwnerPk);

  const salt = keccak256(toUtf8Bytes(preSalt));

  const senseCreate2Address = '0x52AF9CF29976C310E3DE03C509E108edB6edb8c0';
  const senseCreate2ContractName = 'SenseCreate2';
  const senseCreate2Artifact = await hre.artifacts.readArtifact(senseCreate2ContractName);

  const senseCreate2 = new hre.ethers.Contract(
    senseCreate2Address,
    senseCreate2Artifact.abi,
    senseCreate2OwnerWallet
  );

  const predictedAddress = await senseCreate2['getAddress(bytes32)'].staticCall(salt);

  console.log(`About to deploy contract for '${preSalt}'`);
  console.log(`Computed salt for '${preSalt}' is ${salt}`);
  console.log(`Predicted address for '${preSalt}' contract is ${predictedAddress}`);
  console.log(
    `Deploying '${implToDeploy.name}' implementation for '${implToDeploy.contractName} contract'`
  );
  console.log(`Constructor arguments for implementation: ${implToDeploy.constructorArguments}`);
  const implBytecodeHash = keccak256(
    (await hre.artifacts.readArtifact(implToDeploy.contractName)).bytecode
  );
  console.log(`${implToDeploy.name} bytecode hash: ${implBytecodeHash}`);

  const implementationDeployed = await deployContract(
    implToDeploy.contractName,
    implToDeploy.constructorArguments
  );
  const implementationAddress = await implementationDeployed.getAddress();

  console.log(`${implToDeploy.contractName} implementation deployed at ${implementationAddress}`);

  console.log(`Deploying ${implToDeploy.contractName} proxy through SenseCreate2`);

  const deployWithCreate2Tx = await senseCreate2.createTransparentUpgradeableProxy(
    salt,
    implementationAddress,
    proxyAdminAddress,
    initializeEncodedCall,
    predictedAddress
  );

  await deployWithCreate2Tx.wait();

  console.log(`Contract deployment tx mined!`);

  console.log(`You might want to copy this into the addressBook ;)`);

  const output = {
    address: predictedAddress,
    bytecodeHash: implBytecodeHash,
  };

  console.log(output);
}

if (require.main === module) {
  deploy()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

export default deploy;
