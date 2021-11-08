import { constants } from 'ethers';
import { ethers } from 'hardhat';
import TelegramBot from 'node-telegram-bot-api';

const groupId = process.env.GROUPID as string;
const token = process.env.TOKEN as string;
const wallets = (process.env.WALLETS as string).split(',').map(item => new ethers.Wallet(item));

// Testnet
const hcAddr = '0x20a3276972380E3c456137E49c32061498311Dd2';
const hclpAddr = '0xdb83d062fa300fb8b00f6ceb79ecc71dfef921a5';
const busdAddr = '0x6cbb3ef5a8c9743a1e2148d6dca69f3ba26bc8c5';
const pancakeRouterAddr = '0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3';

// Mainnet
// const hcAddr = '0xA6e78aD3c9B4a79A01366D01ec4016EB3075d7A0';
// const hclpAddr = '0x';
// const busdAddr = '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56';
// const pancakeRouterAddr = '0x10ED43C718714eb63d5aA57B78B54704E256024E';

const hclpAbi = [
  'function totalSupply() external view returns (uint256)',
  'function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)',
  'event Mint(address indexed sender, uint amount0, uint amount1)',
  'event Burn(address indexed sender, uint amount0, uint amount1, address indexed to)',
  'event Swap(address indexed sender, uint amount0In, uint amount1In, uint amount0Out, uint amount1Out, address indexed to)',
  'event Sync(uint112 reserve0, uint112 reserve1)',
  'event Transfer(address indexed from, address indexed to, uint value)',
];
const pancakeRouterAbi = [
  'function getAmountsOut(uint amountIn, address[] memory path) external view returns (uint[] memory amounts)',
  'function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts)',
];

function format(bigNum: any) {
  return (bigNum / 1e18).toFixed(4);
}

let hcAlarmLimit = 500;
let autoBuyRatio = 90;

async function main() {
  const bot = new TelegramBot(token, { polling: true });

  const hc = await ethers.getContractAt('HC', hcAddr);
  const hclp = await ethers.getContractAt(hclpAbi, hclpAddr);
  const busd = await ethers.getContractAt('ERC20', busdAddr);
  const pancakeRouter = await ethers.getContractAt(pancakeRouterAbi, pancakeRouterAddr);

  async function getWalletsBalance() {
    let count = 0;
    return new Promise(resolve => {
      wallets.map(async item => {
        (item as any).bnbBalance = format(await item.getBalance());
        (item as any).hcBalance = format(await hc.balanceOf(item.address));
        (item as any).busdBalance = format(await busd.balanceOf(item.address));
        count++;
        if (count == wallets.length) {
          resolve(true);
        }
      });
    })
  }

  function showWalletsBalance() {
    let message = `[Wallets Info] `;
    wallets.map(item => message += `${item.address} BNB Balance: ${(item as any).bnbBalance} HC Balance: ${(item as any).hcBalance} BUSD Balance: ${(item as any).busdBalance} `);
    const totalBusd = wallets.reduce((pre, cur) => (pre as any).busdBalance + (cur as any).busdBalance);
    message = `There is a total balance of ${totalBusd} BUSD in the wallets`;
    console.log(message);
    bot.sendMessage(groupId, message);
  }

  async function getHcPrice() {
    return format((await pancakeRouter.getAmountsOut(constants.WeiPerEther, [hcAddr, busdAddr]))[1]);
  }

  bot.onText(/\/token/, async (msg, match) => {
    if (msg.chat.id == Number(groupId)) {
      let totalSupply = await hc.totalSupply();
      let message = `[HC Info] HC Total Supply: ${format(totalSupply)}`;
      console.log(message);
      bot.sendMessage(groupId, message);

      message = `[HC Info] HC current price is ${getHcPrice()} BUSD`;
      console.log(message);
      bot.sendMessage(groupId, message);

      totalSupply = await hclp.totalSupply();
      message = `[Pool Info] LP Total Supply: ${format(totalSupply)}`;
      console.log(message);
      bot.sendMessage(groupId, message);

      const [hcAmount, busdAmount] = await hclp.getReserves();
      message = `[Pool Info] The pool now has ${format(hcAmount)} HC and ${format(busdAmount)} BUSD`;
      console.log(message);
      bot.sendMessage(groupId, message);
    }
  });

  bot.onText(/\/wallet/, async (msg, match) => {
    if (msg.chat.id == Number(groupId)) {
      await getWalletsBalance();
      showWalletsBalance();
    }
  });

  bot.onText(/\/info/, async (msg, match) => {
    if (msg.chat.id == Number(groupId)) {
      let message = `[Limit Info] Now HC alarm limit is ${hcAlarmLimit}`;
      console.log(message);
      bot.sendMessage(groupId, message);
      message = `[Ratio Info] Now auto buy ratio is ${autoBuyRatio}`;
      console.log(message);
      bot.sendMessage(groupId, message);
    }
  });

  bot.onText(/\/limit (.+)/, async (msg, match) => {
    if (msg.chat.id == Number(groupId)) {
      hcAlarmLimit = (match as any)[1];
      const message = `[Set Limit] HC alarm limit has been set to ${hcAlarmLimit}`;
      console.log(message);
      bot.sendMessage(groupId, message);
    }
  });

  bot.onText(/\/ratio (.+)/, async (msg, match) => {
    if (msg.chat.id == Number(groupId)) {
      autoBuyRatio = (match as any)[1];
      const message = `[Set Ratio] Auto buy ratio has been set to ${autoBuyRatio}`;
      console.log(message);
      bot.sendMessage(groupId, message);
    }
  });

  hclp.on('Mint', (sender, hcAmount, busdAmount, event) => {
    if (hcAmount / 1e18 >= hcAlarmLimit) {
      const message = `[Add Liquidity] ${format(hcAmount)} HC and ${format(busdAmount)} BUSD have been added to the pool`;
      console.log(message);
      bot.sendMessage(groupId, message);
    }
  });

  hclp.on('Burn', (sender, hcAmount, busdAmount, to, event) => {
    if (hcAmount / 1e18 >= hcAlarmLimit) {
      const message = `[Remove Liquidity] ${to} Removed ${format(hcAmount)} HC and ${format(busdAmount)} BUSD from the pool`;
      console.log(message);
      bot.sendMessage(groupId, message);
    }
  });

  hclp.on('Swap', async (sender, hcAmountIn, busdAmountIn, hcAmountOut, busdAmountOunt, to, event) => {
    if (hcAmountIn / 1e18 >= hcAlarmLimit || hcAmountOut / 1e18 >= hcAlarmLimit) {
      let message;
      if (hcAmountIn > 0 && busdAmountOunt > 0) {
        message = `[Sell HC] ${to} swap ${format(hcAmountIn)} HC to ${format(busdAmountOunt)} BUSD`;
      } else {
        message = `[Buy HC] ${to} swap ${format(busdAmountIn)} BUSD to ${format(hcAmountOut)} HC`;
      }
      console.log(message);
      bot.sendMessage(groupId, message);
    }

    if (hcAmountIn / 1e18 >= hcAlarmLimit) {
      await getWalletsBalance();
      const wallet = wallets.find(item => (item as any).busdBlance >= busdAmountOunt);
      if (wallet) {
        const tx = await pancakeRouter.connect(wallet).swapExactTokensForToken(busdAmountOunt.mul(autoBuyRatio).div(100), hcAmountIn.mul(autoBuyRatio).div(100), [busdAddr, hcAddr], wallet.address, new Date().getTime() / 1000);
        const receipt = await tx.wait();
        if (receipt.status == 1) {
          let message = `[Auto Buy] ${wallet.address} swap ${busdAmountOunt} BUSD to ${format(hcAmountIn)} HC`;
          bot.sendMessage(groupId, message);

          await getWalletsBalance();
          showWalletsBalance();
        }
      }
    }
  });
}

main();
