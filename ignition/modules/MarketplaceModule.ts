import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import WilTokenModule from "./WilTokenModule";

export default buildModule("MarketplaceModule", (m) => {
  const owner = m.getAccount(0);

  const { wilToken } = m.useModule(WilTokenModule);

  const implementation = m.contract("NftMarketplace");

  const helper = m.contractAt("NftMarketplace", implementation, {
    id: "MarketplaceImplementation",
  });

  const initData = m.encodeFunctionCall(helper, "initialize", [
    owner,
    wilToken,
  ]);

  const proxy = m.contract(
    "TransparentUpgradeableProxy",
    [implementation, owner, initData],
    {
      id: "MarketplaceProxy",
    },
  );

  const marketplace = m.contractAt("NftMarketplace", proxy, {
    id: "MarketplaceFinal",
  });

  return {
    marketplace,
    implementation,
    proxy,
  };
});
