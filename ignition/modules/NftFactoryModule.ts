import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import NftTokenModule from "./NftTokenModule";

export default buildModule("FactoryModule", (m) => {
  const owner = m.getAccount(0);

  const { implementation: nftImplementation } = m.useModule(NftTokenModule);

  const implementation = m.contract("NftFactory");

  const helper = m.contractAt("NftFactory", implementation, {
    id: "NftFactoryImplementation",
  });

  const initData = m.encodeFunctionCall(helper, "initialize", [
    owner,
    nftImplementation,
  ]);

  const proxy = m.contract(
    "TransparentUpgradeableProxy",
    [implementation, owner, initData],
    {
      id: "FactoryProxy",
    },
  );

  const factory = m.contractAt("NftFactory", proxy, {
    id: "NftFactoryFinal",
  });

  return {
    factory,
    implementation,
    proxy,
  };
});
