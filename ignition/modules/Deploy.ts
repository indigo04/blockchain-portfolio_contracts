import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

import WilTokenModule from "./WilTokenModule";
import NftTokenModule from "./NftTokenModule";
import FactoryModule from "./NftFactoryModule";
import MarketplaceModule from "./MarketplaceModule";

export default buildModule("Deploy", (m) => {
  const { wilToken } = m.useModule(WilTokenModule);

  const { implementation: nftImplementation } = m.useModule(NftTokenModule);

  const { factory } = m.useModule(FactoryModule);

  const { marketplace } = m.useModule(MarketplaceModule);

  return {
    wilToken,
    nftImplementation,
    factory,
    marketplace,
  };
});
