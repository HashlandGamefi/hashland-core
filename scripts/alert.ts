import { constants } from 'ethers';
import { ethers } from 'hardhat';
import TelegramBot from 'node-telegram-bot-api';

const groupId = -670292888;

const hcAddr = '0x20a3276972380E3c456137E49c32061498311Dd2';
const hclpAddr = '0xdb83d062fa300fb8b00f6ceb79ecc71dfef921a5';
const busdAddr = '0x6cbb3ef5a8c9743a1e2148d6dca69f3ba26bc8c5';
const pancakeRouterAddr = '0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3';
const zeroAddr = '0x0000000000000000000000000000000000000000';

const hclpAbi = [
  'event Mint(address indexed sender, uint amount0, uint amount1)',
  'event Burn(address indexed sender, uint amount0, uint amount1, address indexed to)',
  'event Swap(address indexed sender, uint amount0In, uint amount1In, uint amount0Out, uint amount1Out, address indexed to)',
  'event Sync(uint112 reserve0, uint112 reserve1)',
  'event Transfer(address indexed from, address indexed to, uint value)',
];
const pancakeRouterAbi = [
  'function getAmountsOut(uint amountIn, address[] memory path) public view returns (uint[] memory amounts)',
];

function format(bigNum: any) {
  return (bigNum / 1e18).toFixed(4);
}

async function main() {
  const token = process.env.TOKEN as string;
  const bot = new TelegramBot(token, { polling: true });

  const hc = await ethers.getContractAt('HC', hcAddr);
  const hclp = await ethers.getContractAt(hclpAbi, hclpAddr);
  const pancakeRouter = await ethers.getContractAt(pancakeRouterAbi, pancakeRouterAddr);

  bot.onText(/\/info/, async (msg, match) => {
    const chatId = msg.chat.id;
    let totalSupply = await hc.totalSupply();
    let message = `HC Total Supply: ${format(totalSupply)}`;
    console.log(message);
    bot.sendMessage(chatId, message);

    totalSupply = await hclp.totalSupply();
    message = `LP Total Supply: ${format(totalSupply)}`;
    console.log(message);
    bot.sendMessage(chatId, message);
  });

  hclp.on('Mint', (sender, hcAmount, busdAmount, event) => {
    const message = `[Add Liquidity] ${format(hcAmount)} HC and ${format(busdAmount)} BUSD have been added to the pool`;
    console.log(message);
    bot.sendMessage(groupId, message);
  });

  hclp.on('Burn', (sender, hcAmount, busdAmount, to, event) => {
    const message = `[Remove Liquidity] Removed ${format(hcAmount)} HC and ${format(busdAmount)} BUSD from the pool`;
    console.log(message);
    bot.sendMessage(groupId, message);
  });

  hclp.on('Swap', (sender, hcAmountIn, busdAmountIn, hcAmountOut, busdAmountOunt, to, event) => {
    let message;
    if (hcAmountIn > 0 && busdAmountOunt > 0) {
      message = `[Sell HC] ${to} swap ${format(hcAmountIn)} HC to ${format(busdAmountOunt)} BUSD`;
    } else {
      message = `[Buy HC] ${to} swap ${format(busdAmountIn)} BUSD to ${format(hcAmountOut)} HC`;
    }
    console.log(message);
    bot.sendMessage(groupId, message);
  });

  hclp.on('Sync', async (hcAmount, busdAmount, event) => {
    let message = `[Pool Info] The pool now has ${format(hcAmount)} HC and ${format(busdAmount)} BUSD`;
    console.log(message);
    bot.sendMessage(groupId, message);

    const hcPrice = (await pancakeRouter.getAmountsOut(constants.WeiPerEther, [hcAddr, busdAddr]))[1];
    message = `[HC Info] HC current price is ${format(hcPrice)} BUSD`;
    console.log(message);
    bot.sendMessage(groupId, message);
  });

  const filterMintLP = hclp.filters.Transfer(zeroAddr);
  hclp.on(filterMintLP, (from, to, amount, event) => {
    const message = `[Mint LP] ${to} got ${format(amount)} LP`;
    console.log(message);
    bot.sendMessage(groupId, message);
  });

  const filterBurnLP = hclp.filters.Transfer(null, hclpAddr);
  hclp.on(filterBurnLP, (from, to, amount, event) => {
    const message = `[Burn LP] ${from} lost ${format(amount)} LP`;
    console.log(message);
    bot.sendMessage(groupId, message);
  });
}

main();
