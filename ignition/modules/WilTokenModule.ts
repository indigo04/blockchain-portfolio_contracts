import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("WilTokenModule", (m) => {
  const owner = m.getAccount(0);

  const implementation = m.contract("WilToken");

  const helper = m.contractAt("WilToken", implementation, {
    id: "WilTokenImplementation",
  });

  const initData = m.encodeFunctionCall(helper, "initialize", [owner]);

  const proxy = m.contract(
    "TransparentUpgradeableProxy",
    [implementation, owner, initData],
    {
      id: "WilTokenProxy",
    },
  );

  const wilToken = m.contractAt("WilToken", proxy, {
    id: "WilTokenFinal",
  });

  return {
    wilToken,
    proxy,
    implementation,
  };
});
