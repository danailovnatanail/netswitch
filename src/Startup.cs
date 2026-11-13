using System;
using System.IO;
using System.Security;
using System.Security.Principal;
using System.Text;
using System.Windows.Forms;

namespace NetSwitch
{
    /// <summary>
    /// Avvio automatico all'accesso tramite Utilità di pianificazione (con privilegi elevati,
    /// così non compare il prompt UAC a ogni avvio).
    /// </summary>
    public static class Startup
    {
        const string TaskName = "NetSwitch";

        static string Schtasks { get { return Path.Combine(Environment.SystemDirectory, "schtasks.exe"); } }

        public static bool IsEnabled()
        {
            return NetOps.RunProcess(Schtasks, "/query /tn \"" + TaskName + "\"").Ok;
        }

        public static OpResult Enable()
        {
            string user = WindowsIdentity.GetCurrent().Name;
            string exe = Application.ExecutablePath;
            string xml =
                "<?xml version=\"1.0\" encoding=\"UTF-16\"?>\r\n" +
                "<Task version=\"1.2\" xmlns=\"http://schemas.microsoft.com/windows/2004/02/mit/task\">\r\n" +
                "  <RegistrationInfo><Description>NetSwitch - gestione interfacce di rete</Description></RegistrationInfo>\r\n" +
                "  <Triggers><LogonTrigger><Enabled>true</Enabled><UserId>" + SecurityElement.Escape(user) + "</UserId><Delay>PT5S</Delay></LogonTrigger></Triggers>\r\n" +
                "  <Principals><Principal id=\"Author\"><UserId>" + SecurityElement.Escape(user) + "</UserId><LogonType>InteractiveToken</LogonType><RunLevel>HighestAvailable</RunLevel></Principal></Principals>\r\n" +
                "  <Settings>\r\n" +
                "    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>\r\n" +
                "    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>\r\n" +
                "    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>\r\n" +
                "    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>\r\n" +
                "    <Priority>7</Priority>\r\n" +
                "  </Settings>\r\n" +
                "  <Actions Context=\"Author\"><Exec><Command>" + SecurityElement.Escape(exe) + "</Command><Arguments>--background</Arguments></Exec></Actions>\r\n" +
                "</Task>\r\n";
            string tmp = Path.Combine(Path.GetTempPath(), "netswitch_task_" + Guid.NewGuid().ToString("N") + ".xml");
            try
            {
                File.WriteAllText(tmp, xml, Encoding.Unicode);
                var r = NetOps.RunProcess(Schtasks, "/create /tn \"" + TaskName + "\" /xml \"" + tmp + "\" /f");
                return r.Ok ? new OpResult(true, "NetSwitch verrà avviato all'accesso a Windows.") : r;
            }
            finally
            {
                try { File.Delete(tmp); } catch { }
            }
        }

        public static OpResult Disable()
        {
            var r = NetOps.RunProcess(Schtasks, "/delete /tn \"" + TaskName + "\" /f");
            return r.Ok ? new OpResult(true, "Avvio automatico disattivato.") : r;
        }
    }
}
