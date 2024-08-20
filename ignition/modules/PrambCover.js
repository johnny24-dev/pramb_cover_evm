const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");


module.exports = buildModule("PrambCoverModule", (m) => {
  const admin_addr = m.getParameter("_admin", `0x2A7cB50213Be8F8Ce5E36F1c01963Dd7483eF848` );
  const tresury_addr = m.getParameter("_treasury", `0x2A7cB50213Be8F8Ce5E36F1c01963Dd7483eF848`);

  const pramb_cover = m.contract("PrambCover", [admin_addr,tresury_addr]);

  return { pramb_cover };
});
