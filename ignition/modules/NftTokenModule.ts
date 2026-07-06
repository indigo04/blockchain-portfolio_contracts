import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("NftTokenModule", (m) => {
  const implementation = m.contract("NftToken");

  return {
    implementation,
  };
});
